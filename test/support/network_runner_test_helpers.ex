defmodule Panic.NetworkRunnerTestHelpers do
  @moduledoc """
  Test helpers for NetworkRunner testing that provide clean, predictable test execution.

  This module provides utilities to:
  - Enable/disable synchronous mode for NetworkRunner
  - Clean up registry entries surgically
  - Manage database access for async tasks
  - Common assertions for NetworkRunner state
  """

  import ExUnit.Assertions
  import ExUnit.Callbacks

  alias Ecto.Adapters.SQL.Sandbox
  alias Panic.Engine.NetworkRegistry

  @doc """
  Enables synchronous mode for NetworkRunner during tests.

  In synchronous mode, NetworkRunner processes invocations in the same process
  instead of spawning async tasks, making tests predictable and avoiding
  database connection ownership issues.

  ## Usage

      setup do
        NetworkRunnerTestHelpers.enable_sync_mode()
        on_exit(&NetworkRunnerTestHelpers.disable_sync_mode/0)
      end
  """
  def enable_sync_mode do
    Application.put_env(:panic, :sync_network_runner, true)
  end

  @doc """
  Disables synchronous mode for NetworkRunner.

  Returns NetworkRunner to its default async behavior.
  """
  def disable_sync_mode do
    Application.put_env(:panic, :sync_network_runner, false)
  end

  @doc """
  Stops a specific NetworkRunner process by network ID.

  This provides surgical cleanup compared to stopping all runners,
  allowing tests to clean up only their own processes.

  ## Parameters
  - `network_id` - The ID of the network whose runner should be stopped

  ## Returns
  - `:ok` - Process was stopped or didn't exist

  ## Usage

      setup %{network: network} do
        on_exit(fn -> NetworkRunnerTestHelpers.stop_network_runner(network.id) end)
      end
  """
  def stop_network_runner(network_id) do
    case Registry.lookup(NetworkRegistry, network_id) do
      [{pid, _}] when is_pid(pid) ->
        if Process.alive?(pid) do
          DynamicSupervisor.terminate_child(Panic.Engine.NetworkSupervisor, pid)

          # Wait for process to terminate
          ref = Process.monitor(pid)

          receive do
            {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
          after
            # Continue even if timeout
            1000 -> :ok
          end
        end

        :ok

      [] ->
        :ok
    end
  end

  @doc """
  Allows database access for a NetworkRunner process.

  This grants Ecto Sandbox access to the NetworkRunner GenServer,
  enabling it to perform database operations during tests.

  ## Parameters
  - `network_id` - The ID of the network whose runner needs DB access

  ## Usage

      # After starting a network runner
      {:ok, _invocation} = NetworkRunner.start_run(network.id, "test prompt", user)
      NetworkRunnerTestHelpers.allow_network_runner_db_access(network.id)
  """
  def allow_network_runner_db_access(network_id) do
    case Registry.lookup(NetworkRegistry, network_id) do
      [{pid, _}] when is_pid(pid) ->
        Sandbox.allow(Panic.Repo, self(), pid)
        :ok

      [] ->
        :ok
    end
  end

  @doc """
  Asserts that a NetworkRunner is in idle state.

  ## Parameters
  - `network_id` - The network ID to check

  ## Usage

      NetworkRunnerTestHelpers.assert_runner_idle(network.id)
  """
  def assert_runner_idle(network_id) do
    case Registry.lookup(NetworkRegistry, network_id) do
      [{pid, _}] ->
        state = :sys.get_state(pid)
        assert state.genesis_invocation == nil
        assert state.current_invocation == nil

      [] ->
        # No runner exists, which is also idle
        :ok
    end
  end

  @doc """
  Asserts that a NetworkRunner is in running state.

  ## Parameters
  - `network_id` - The network ID to check
  - `expected_user` - Optional user that should be associated with the run

  ## Usage

      NetworkRunnerTestHelpers.assert_runner_running(network.id, user)
  """
  def assert_runner_running(network_id, expected_user \\ nil) do
    case Registry.lookup(NetworkRegistry, network_id) do
      [{pid, _}] ->
        state = :sys.get_state(pid)
        assert state.genesis_invocation != nil
        assert state.current_invocation != nil

        if expected_user do
          assert state.user.id == expected_user.id
        end

        state

      [] ->
        flunk("Expected NetworkRunner to be running, but none exists for network #{network_id}")
    end
  end

  @doc """
  Gets the current state of a NetworkRunner process.

  ## Parameters
  - `network_id` - The network ID to get state for

  ## Returns
  - `{:ok, state}` - The current GenServer state
  - `{:error, :not_found}` - No runner exists for this network

  ## Usage

      {:ok, state} = NetworkRunnerTestHelpers.get_runner_state(network.id)
      assert state.genesis_invocation.input == "test prompt"
  """
  def get_runner_state(network_id) do
    case Registry.lookup(NetworkRegistry, network_id) do
      [{pid, _}] ->
        {:ok, :sys.get_state(pid)}

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Waits for NetworkRunner to complete processing in synchronous mode.

  In sync mode, this ensures the GenServer has processed all messages
  before continuing with test assertions.

  ## Parameters
  - `network_id` - The network ID to wait for
  - `timeout` - Maximum time to wait in milliseconds (default: 1000)

  ## Usage

      NetworkRunner.start_run(network.id, "test", user)
      NetworkRunnerTestHelpers.wait_for_sync_completion(network.id)
      # Now safe to make assertions about the final state
  """
  def wait_for_sync_completion(network_id, timeout \\ 1000) do
    case Registry.lookup(NetworkRegistry, network_id) do
      [{pid, _}] ->
        # In sync mode, we need to ensure any :processing_completed messages are handled
        # First, give a small moment for the message to be sent to self()
        Process.sleep(1)

        # Then send a synchronous call to ensure all messages are processed
        try do
          GenServer.call(pid, :get_state, timeout)
          # Give another moment for message processing
          Process.sleep(1)
          GenServer.call(pid, :get_state, timeout)
        catch
          # Process ended, which is fine
          :exit, {:noproc, _} -> :ok
          # Timeout is acceptable
          :exit, {:timeout, _} -> :ok
        end

      [] ->
        :ok
    end
  end

  @doc """
  Sets up a test with synchronous NetworkRunner mode and cleanup.

  This is a convenience function that combines common setup steps:
  - Enables synchronous mode
  - Sets up cleanup on exit
  - Optionally allows DB access for a network

  ## Parameters
  - `opts` - Options for setup
    - `:network_id` - If provided, will set up cleanup for this specific network
    - `:allow_db` - If true, will allow DB access for the network

  ## Usage

      setup %{network: network} do
        NetworkRunnerTestHelpers.setup_sync_test(network_id: network.id, allow_db: true)
      end
  """
  def setup_sync_test(opts \\ []) do
    enable_sync_mode()

    on_exit(fn ->
      disable_sync_mode()

      if network_id = opts[:network_id] do
        stop_network_runner(network_id)
      end
    end)

    if opts[:allow_db] && opts[:network_id] do
      # Allow DB access after any potential runner start
      allow_network_runner_db_access(opts[:network_id])
    end

    :ok
  end
end
