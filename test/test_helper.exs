# Configure ExUnit to exclude API tests by default
ExUnit.start(exclude: [apikeys: true])

# Setup Repatch for mocking in tests - use shared mode so spawned tasks also get patches
Repatch.setup(enable_global: true, enable_shared: true)

Ecto.Adapters.SQL.Sandbox.mode(Panic.Repo, :manual)

# Archiving is now skipped in test environment via Mix.env() check in NetworkRunner
# These patches are kept for any remaining direct archiver tests
Repatch.patch(Panic.Engine.Archiver, :download_file, fn _url ->
  {:ok, "/tmp/dummy_file.webp"}
end)

Repatch.patch(Panic.Engine.Archiver, :convert_file, fn filename, _dest_rootname ->
  {:ok, filename}
end)

Repatch.patch(Panic.Engine.Archiver, :upload_to_s3, fn _file_path ->
  {:ok, "https://dummy-s3-url.com/test-file.webp"}
end)

defmodule Panic.Generators do
  @moduledoc """
  StreamData generators for Panic resources.
  """
  use ExUnitProperties

  alias Panic.Accounts.User
  alias Panic.Engine.Network
  alias Panic.Platforms.Dummy

  def ascii_sentence do
    :ascii
    |> string(min_length: 1)
    |> map(&String.trim/1)
    |> filter(&(String.length(&1) > 0))
  end

  def model(filters \\ []) do
    # Get all models matching the filters
    all_matching = Panic.Model.all(filters)

    # Get dummy models matching the filters
    dummy_matching = Enum.filter(all_matching, &(&1.platform == Dummy))

    # If we have at least 3 dummy models matching the filters, use only dummy models
    # Otherwise, use all models to avoid filter issues
    models_to_use =
      if length(dummy_matching) >= 3 do
        dummy_matching
      else
        all_matching
      end

    member_of(models_to_use)
  end

  def real_model(filters \\ []) do
    filters
    |> Panic.Model.all()
    |> member_of()
    |> filter(fn model -> model.platform != Dummy end)
  end

  def password do
    :utf8
    |> string(min_length: 8)
    |> filter(fn s -> not Regex.match?(~r/^[[:space:]]*$/, s) end)
    |> filter(fn s -> String.length(s) >= 8 end)
  end

  def email do
    fn -> System.unique_integer([:positive]) end
    |> repeatedly()
    |> map(fn i -> "user-#{i}@example.com" end)
  end

  def user(password_generator \\ password()) do
    gen all(email <- email(), password <- password_generator) do
      User
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{email: email, password: password, password_confirmation: password}
      )
      |> Ash.create!()
    end
  end

  def user_with_real_tokens(password_generator \\ password()) do
    gen all(user <- user(password_generator)) do
      # Read API keys from environment variables
      openai_key = System.get_env("OPENAI_API_KEY")
      replicate_key = System.get_env("REPLICATE_API_KEY")
      gemini_key = System.get_env("GOOGLE_AI_STUDIO_TOKEN")

      # For apikeys tests, fail if keys are not present
      if openai_key == nil || replicate_key == nil || gemini_key == nil do
        raise "API keys required for this test. Set OPENAI_API_KEY, REPLICATE_API_KEY, and GOOGLE_AI_STUDIO_TOKEN environment variables."
      end

      # Set the tokens from environment variables
      user
      |> Panic.Accounts.set_token!(:openai_token, openai_key, actor: user)
      |> Panic.Accounts.set_token!(:replicate_token, replicate_key, actor: user)
      |> Panic.Accounts.set_token!(:gemini_token, gemini_key, actor: user)
      |> then(fn user -> Ash.get!(User, user.id, actor: user) end)
    end
  end

  def network(user) do
    gen all(input <- Ash.Generator.action_input(Network, :create)) do
      # Override lockout_seconds to 1 for tests
      input_with_lockout = Map.put(input, :lockout_seconds, 1)

      Network
      |> Ash.Changeset.for_create(:create, input_with_lockout, actor: user)
      |> Ash.create!()
    end
  end

  def network_with_dummy_models(user) do
    gen all(network <- network(user), length <- integer(1..5)) do
      # Create a simple chain of dummy models (flat list – vestaboards removed)
      model_ids =
        case length do
          1 -> ["dummy-t2t"]
          2 -> ["dummy-t2i", "dummy-i2t"]
          3 -> ["dummy-t2i", "dummy-i2i", "dummy-i2t"]
          4 -> ["dummy-t2a", "dummy-a2i", "dummy-i2i", "dummy-i2t"]
          _ -> ["dummy-t2i", "dummy-i2a", "dummy-a2i", "dummy-i2i", "dummy-i2t"]
        end

      Panic.Engine.update_models!(network, model_ids, actor: user)
    end
  end

  def network_with_real_models(user) do
    gen all(network <- network(user), length <- integer(1..10)) do
      model_ids =
        :text
        |> Stream.unfold(fn input_type ->
          next_model = [input_type: input_type] |> real_model() |> pick()
          {next_model, Map.fetch!(next_model, :output_type)}
        end)
        |> Stream.transform([], fn model, acc ->
          if length(acc) >= length && acc |> List.last() |> Map.fetch!(:output_type) == :text do
            {:halt, acc}
          else
            {[model], acc ++ [model]}
          end
        end)
        |> Enum.map(fn %Panic.Model{id: id} -> [id] end)

      Panic.Engine.update_models!(network, model_ids, actor: user)
    end
  end

  def invocation(network) do
    user = Ash.get!(User, network.user_id, authorize?: false)

    gen all(input <- Panic.Generators.ascii_sentence()) do
      Panic.Engine.Invocation
      |> Ash.Changeset.for_create(:prepare_first, %{input: input, network: network}, actor: user)
      |> Ash.create!()
    end
  end
end

defmodule Panic.Fixtures do
  @moduledoc """
  Test fixtures for Panic resources.
  """
  use ExUnitProperties

  def user(password) do
    password
    |> StreamData.constant()
    |> Panic.Generators.user()
    |> pick()
  end

  def user do
    pick(Panic.Generators.user())
  end

  def user_with_real_tokens(password) do
    password
    |> StreamData.constant()
    |> Panic.Generators.user_with_real_tokens()
    |> pick()
  end

  def user_with_real_tokens do
    pick(Panic.Generators.user_with_real_tokens())
  end

  def network(user) do
    user
    |> Panic.Generators.network()
    |> pick()
  end

  def network_with_dummy_models(user) do
    user
    |> Panic.Generators.network_with_dummy_models()
    |> pick()
  end

  def network_with_real_models(user) do
    user
    |> Panic.Generators.network_with_real_models()
    |> pick()
  end
end

defmodule PanicWeb.Helpers do
  @moduledoc false
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
end

defmodule PanicWeb.Helpers.DatabasePatches do
  @moduledoc """
  Convenience module for setting up database patches in test modules.

  ## Usage

      defmodule MyTest do
        use ExUnit.Case, async: false
        use PanicWeb.Helpers.DatabasePatches

        # Your tests here...
      end

  This is equivalent to adding:

      setup_all do
        PanicWeb.Helpers.setup_database_patches()
        :ok
      end
  """

  defmacro __using__(_opts) do
    quote do
      setup_all do
        PanicWeb.Helpers.setup_database_patches()
        :ok
      end
    end
  end
end
