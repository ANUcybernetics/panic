defmodule PanicWeb.Helpers do
  @moduledoc """
  Helper functions for Phoenix and LiveView tests.
  """
  alias AshAuthentication.Plug.Helpers
  alias Panic.Accounts.User

  def create_and_sign_in_user(%{conn: conn}) do
    password = "abcd1234"
    user = Panic.Fixtures.user(password)

    strategy = AshAuthentication.Info.strategy!(User, :password)

    {:ok, user} =
      AshAuthentication.Strategy.action(strategy, :sign_in, %{
        email: user.email,
        password: password
      })

    %{
      conn:
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Helpers.store_in_session(user),
      user: user
    }
  end

  def create_and_sign_in_user_with_real_tokens(%{conn: conn}) do
    password = "abcd1234"

    # Create user with real tokens for apikeys tests
    user = Panic.Fixtures.user_with_real_tokens(password)

    strategy = AshAuthentication.Info.strategy!(User, :password)

    {:ok, user} =
      AshAuthentication.Strategy.action(strategy, :sign_in, %{
        email: user.email,
        password: password
      })

    %{
      conn:
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Helpers.store_in_session(user),
      user: user
    }
  end

  @doc """
  Stop all NetworkRunner processes for test cleanup.

  ## Problem

  NetworkRunner GenServers are started on-demand and registered in the NetworkRegistry.
  These processes persist across test runs and maintain user state in their internal state.
  When tests run together (even with `async: false`), NetworkRunner processes from
  previous tests may still be running and processing invocations.

  This causes Ash.Error.Forbidden errors when a NetworkRunner tries to call actions like
  `about_to_invoke` with a stale user context that doesn't match the current test's user.
  The error occurs because the authorization policy `relates_to_actor_via([:network, :user])`
  fails when the actor doesn't match the network's owner.

  ## Solution

  This helper stops all NetworkRunner GenServers before each test runs, ensuring:
  1. No stale processes continue running with old user contexts
  2. Each test starts with a clean NetworkRunner state
  3. Authorization policies work correctly with the proper actor

  ## Usage

  Call this in test setup blocks before creating users and networks:

      setup do
        PanicWeb.Helpers.stop_all_network_runners()
        :ok
      end
  """
  def stop_all_network_runners do
    # Get all running NetworkRunner processes
    registry_entries = Registry.select(Panic.Engine.NetworkRegistry, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}])

    # Stop each NetworkRunner
    pids =
      registry_entries
      |> Enum.map(fn {_network_id, pid} ->
        if Process.alive?(pid) do
          DynamicSupervisor.terminate_child(Panic.Engine.NetworkSupervisor, pid)
          pid
        end
      end)
      |> Enum.filter(& &1)

    # Wait for all processes to terminate
    Enum.each(pids, fn pid ->
      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
      after
        1000 -> :timeout
      end
    end)

    # Wait for and terminate any remaining async tasks
    task_supervisor = Panic.Engine.TaskSupervisor

    if Process.whereis(task_supervisor) do
      # Get all running task PIDs
      task_pids = Task.Supervisor.children(task_supervisor)

      # Terminate each task and wait for completion
      Enum.each(task_pids, fn pid ->
        if Process.alive?(pid) do
          # Monitor the task before terminating
          ref = Process.monitor(pid)
          Task.Supervisor.terminate_child(task_supervisor, pid)

          # Wait for the task to actually terminate
          receive do
            {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
          after
            500 -> :timeout
          end
        end
      end)
    end

    # Wait for any database transactions to complete
    Process.sleep(200)

    :ok
  end

  @doc """
  Sets up database connection patches for NetworkRunner and async task testing.

  This function patches Task.Supervisor.start_child to prevent database connection
  ownership issues that cause TransportError and DBConnection.OwnershipError.

  The patch ensures that async tasks started by NetworkRunner processes run in
  the same process context, avoiding database connection ownership problems.

  ## Usage

  Call this in setup_all blocks for tests that use NetworkRunner or async tasks:

      setup_all do
        PanicWeb.Helpers.setup_database_patches()
        :ok
      end

  Or use the convenience macro:

      use PanicWeb.Helpers.DatabasePatches
  """
  def setup_database_patches do
    Repatch.patch(Task.Supervisor, :start_child, [mode: :global], fn _supervisor, fun ->
      fun.()
      {:ok, self()}
    end)

    :ok
  end

  @doc """
  Allows database access for NetworkRunner processes.

  This helper grants database sandbox access to NetworkRunner GenServers,
  which is necessary when they need to perform database operations during
  invocation processing.

  ## Usage

  Call this after creating a network but before starting runs:

      network = create_network(user)
      PanicWeb.Helpers.allow_network_runner_db_access(network.id)

  ## Parameters

  - `network_id`: The ID of the network whose NetworkRunner process needs database access
  """
  def allow_network_runner_db_access(network_id) do
    alias Ecto.Adapters.SQL.Sandbox
    alias Panic.Engine.NetworkRegistry

    case Registry.lookup(NetworkRegistry, network_id) do
      [{pid, _}] -> Sandbox.allow(Panic.Repo, self(), pid)
      [] -> :ok
    end
  end

  @doc """
  Enables synchronous NetworkRunner mode for web tests.

  When enabled, NetworkRunner processes invocations synchronously instead
  of spawning async tasks. This prevents database connection ownership
  issues and makes tests more predictable.
  """
  def enable_sync_network_runner do
    Application.put_env(:panic, :sync_network_runner, true)
  end

  @doc """
  Disables synchronous NetworkRunner mode.

  Returns NetworkRunner to its default async behavior.
  """
  def disable_sync_network_runner do
    Application.put_env(:panic, :sync_network_runner, false)
  end

  @doc """
  Sets up web tests with proper NetworkRunner cleanup and synchronous mode.

  This is a convenience function that combines common web test setup:
  - Stops all existing NetworkRunner processes
  - Enables synchronous mode
  - Sets up cleanup on exit
  """
  def setup_web_test do
    stop_all_network_runners()
    enable_sync_network_runner()

    ExUnit.Callbacks.on_exit(fn ->
      stop_all_network_runners()
      disable_sync_network_runner()
    end)

    :ok
  end
end