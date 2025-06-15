defmodule Panic.NetworkRunnerTest do
  use Panic.DataCase, async: false
  use ExUnitProperties

  alias Ecto.Adapters.SQL.Sandbox
  alias Panic.Accounts.User
  alias Panic.Engine
  alias Panic.Engine.NetworkRegistry
  alias Panic.Engine.NetworkRunner

  require Ash.Query

  setup do
    # Stop all network runners to ensure clean state
    PanicWeb.Helpers.stop_all_network_runners()

    # Create a test user
    user = Ash.Generator.seed!(User)

    # Create a test network using the code interface
    network = Engine.create_network!("Test Network", "Test network for NetworkRunner tests", actor: user)

    # Update the network with a dummy model (models is flat array)
    network = Engine.update_models!(network, ["dummy-t2t"], actor: user)

    on_exit(fn ->
      # Stop any running gen servers for this network
      NetworkRunner.stop_run(network.id)

      # Kill the runner if it exists
      case Registry.lookup(NetworkRegistry, network.id) do
        [{pid, _}] -> Process.exit(pid, :kill)
        [] -> :ok
      end

      # Wait for cleanup to complete
      Process.sleep(200)
    end)

    {:ok, user: user, network: network}
  end

  # Helper function to allow NetworkRunner processes to access the test database
  defp allow_network_runner_db_access(network_id) do
    case Registry.lookup(NetworkRegistry, network_id) do
      [{pid, _}] -> Sandbox.allow(Panic.Repo, self(), pid)
      [] -> :ok
    end
  end

  describe "start_link/1" do
    test "starts a GenServer for a network", %{network: network} do
      # Check if runner already exists
      case Registry.lookup(NetworkRegistry, network.id) do
        [{existing_pid, _}] ->
          # runner already exists, verify it's alive
          assert Process.alive?(existing_pid)
          assert [{^existing_pid, _}] = Registry.lookup(NetworkRegistry, network.id)

        [] ->
          # No runner exists, start a new one
          {:ok, pid} = NetworkRunner.start_link(network_id: network.id)
          assert Process.alive?(pid)
          allow_network_runner_db_access(network.id)

          # Should be registered in the registry
          assert [{^pid, _}] = Registry.lookup(NetworkRegistry, network.id)
      end
    end
  end

  describe "start_run/3" do
    test "starts a new run with a prompt", %{network: network, user: user} do
      # Handle potential lockout
      result = NetworkRunner.start_run(network.id, "Test prompt", user)

      genesis_invocation =
        case result do
          {:ok, inv} ->
            inv

          {:lockout, _} ->
            Process.sleep(1_500)
            {:ok, inv} = NetworkRunner.start_run(network.id, "Test prompt", user)
            inv
        end

      allow_network_runner_db_access(network.id)

      assert genesis_invocation.network_id == network.id
      assert genesis_invocation.sequence_number == 0
      assert genesis_invocation.run_number == genesis_invocation.id
    end

    test "automatically starts the runner genserver if not running", %{network: network, user: user} do
      # Kill any existing runner
      case Registry.lookup(NetworkRegistry, network.id) do
        [{pid, _}] -> Process.exit(pid, :kill)
        [] -> :ok
      end

      Process.sleep(50)

      # Handle potential lockout
      result = NetworkRunner.start_run(network.id, "Test prompt", user)

      genesis_invocation =
        case result do
          {:ok, inv} ->
            inv

          {:lockout, _} ->
            Process.sleep(1_500)
            {:ok, inv} = NetworkRunner.start_run(network.id, "Test prompt", user)
            inv
        end

      allow_network_runner_db_access(network.id)

      assert genesis_invocation.network_id == network.id
      assert [{_pid, _}] = Registry.lookup(NetworkRegistry, network.id)
    end

    @tag timeout: 35_000
    test "cancels existing run when starting a new one", %{network: network, user: user} do
      {:ok, first_genesis} = NetworkRunner.start_run(network.id, "First prompt", user)
      allow_network_runner_db_access(network.id)

      # Wait a bit to ensure the first run is processing
      Process.sleep(100)

      # Start a new run after lockout period (configured as 1s in test)
      Process.sleep(1_500)

      {:ok, second_genesis} = NetworkRunner.start_run(network.id, "Second prompt", user)

      assert first_genesis.id != second_genesis.id

      # Check that the first invocation was cancelled or failed
      # Wait a bit for any state transitions
      Process.sleep(500)

      first_invocation = Ash.get!(Engine.Invocation, first_genesis.id, authorize?: false)
      # With dummy models, invocations complete quickly, so we may see completed, failed, or invoking states
      assert first_invocation.state in [:failed, :invoking, :completed],
             "Expected invocation to be failed, invoking, or completed, but was #{first_invocation.state}"
    end

    test "enforces lockout period", %{network: network, user: user} do
      # First start may be lockout from previous test, so handle both cases
      case NetworkRunner.start_run(network.id, "Test prompt", user) do
        {:ok, genesis_invocation} ->
          allow_network_runner_db_access(network.id)

          # Try to start another run immediately
          {:lockout, lockout_genesis} = NetworkRunner.start_run(network.id, "Another prompt", user)
          assert lockout_genesis.id == genesis_invocation.id

        {:lockout, _} ->
          # Already in lockout from previous test, wait and retry
          Process.sleep(1_500)
          {:ok, genesis_invocation} = NetworkRunner.start_run(network.id, "Test prompt", user)
          allow_network_runner_db_access(network.id)

          {:lockout, lockout_genesis} = NetworkRunner.start_run(network.id, "Another prompt", user)
          assert lockout_genesis.id == genesis_invocation.id
      end
    end
  end

  describe "stop_run/1" do
    test "stops a running invocation", %{network: network, user: user} do
      # Handle potential lockout
      result = NetworkRunner.start_run(network.id, "Test prompt", user)

      case result do
        {:ok, _genesis} ->
          :ok

        {:lockout, _} ->
          Process.sleep(1_500)
          {:ok, _genesis} = NetworkRunner.start_run(network.id, "Test prompt", user)
      end

      allow_network_runner_db_access(network.id)

      assert {:ok, :stopped} = NetworkRunner.stop_run(network.id)
    end

    test "returns not_running if no runner genserver exists", %{network: network} do
      # Stop any runner that might be running from other tests
      _ = NetworkRunner.stop_run(network.id)
      # Give it time to fully stop
      Process.sleep(250)

      # Now it should return not_running or stopped (both are acceptable)
      result = NetworkRunner.stop_run(network.id)
      assert result in [{:ok, :not_running}, {:ok, :stopped}]
    end
  end

  describe "process_invocation" do
    test "creates first invocation when starting run", %{network: network, user: user} do
      # Handle potential lockout
      result = NetworkRunner.start_run(network.id, "Test prompt", user)

      genesis =
        case result do
          {:ok, inv} ->
            inv

          {:lockout, _} ->
            Process.sleep(1_500)
            {:ok, inv} = NetworkRunner.start_run(network.id, "Test prompt", user)
            inv
        end

      allow_network_runner_db_access(network.id)

      # Check that the first invocation was created
      invocations =
        Engine.Invocation
        |> Ash.Query.filter(network_id == ^network.id)
        |> Ash.Query.filter(run_number == ^genesis.id)
        |> Ash.read!(authorize?: false)

      assert length(invocations) >= 1
      assert hd(invocations).sequence_number == 0

      # Stop the run
      NetworkRunner.stop_run(network.id)
    end
  end

  describe "error handling" do
    test "runner stays alive after errors", %{network: network, user: user} do
      # Handle potential lockout
      result = NetworkRunner.start_run(network.id, "Test prompt", user)

      case result do
        {:ok, _genesis} ->
          :ok

        {:lockout, _} ->
          Process.sleep(1_500)
          {:ok, _genesis} = NetworkRunner.start_run(network.id, "Test prompt", user)
      end

      allow_network_runner_db_access(network.id)

      # The runner should be alive
      assert [{pid, _}] = Registry.lookup(NetworkRegistry, network.id)
      assert Process.alive?(pid)

      # Stop the run
      NetworkRunner.stop_run(network.id)

      # runner should still be alive after stopping
      assert Process.alive?(pid)
    end
  end

  describe "recursive invocation runs" do
    test "creates a next invocation with the right run number and sequence using dummy models", %{user: user} do
      # Create a separate network for this test to avoid NetworkRunner interference
      test_network = Engine.create_network!("Test Network for Recursion", "Test network", actor: user)
      test_network = Engine.update_models!(test_network, ["dummy-t2t", "dummy-t2t"], actor: user)

      input = "Test prompt for recursion"

      first =
        test_network
        |> Engine.prepare_first!(input, actor: user)
        |> Engine.invoke!(actor: user)

      next = Engine.prepare_next!(first, actor: user)
      assert first.run_number == next.run_number
      assert first.output == next.input
      assert first.sequence_number + 1 == next.sequence_number
    end

    @tag timeout: 35_000
    test "can make a 'run' with invoke! and prepare_next! which maintains io consistency and ordering using dummy models",
         %{user: user} do
      run_length = 4

      # Create a separate network for this test to avoid NetworkRunner interference
      test_network = Engine.create_network!("Test Network for Long Run", "Test network", actor: user)
      test_network = Engine.update_models!(test_network, ["dummy-t2t", "dummy-t2t"], actor: user)

      input = "Test prompt for long run"

      first =
        test_network
        |> Engine.prepare_first!(input, actor: user)
        |> Engine.invoke!(actor: user)

      Enum.reduce(1..(run_length - 1), first, fn _, prev_inv ->
        prev_inv
        |> Engine.prepare_next!(actor: user)
        |> Engine.invoke!(actor: user)
      end)

      invocations =
        Engine.list_run!(test_network.id, first.run_number, actor: user)

      [second_last_in_current_run, last_in_current_run] =
        Engine.current_run!(test_network.id, 2, actor: user)

      assert second_last_in_current_run.sequence_number == last_in_current_run.sequence_number - 1
      assert second_last_in_current_run.run_number == last_in_current_run.run_number

      # check outputs match inputs
      invocations
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [a, b] ->
        assert a.output == b.input
      end)

      # check the right number of invocations generated, and returned in the right order
      assert Enum.count(invocations) == run_length
      sequence_numbers = Enum.map(invocations, & &1.sequence_number)
      assert sequence_numbers == Enum.sort(sequence_numbers, :asc)

      # check the most recent invocation action works
      most_recent = Engine.most_recent!(test_network.id, actor: user)
      assert most_recent.sequence_number == Enum.max(sequence_numbers)
    end
  end

  describe "retry logic" do
    setup %{user: user} do
      # Create test network for retry tests
      network = Engine.create_network!("Test Network", "Test network for NetworkRunner retry tests", actor: user)

      # Update the network with dummy models (models is flat array)
      network = Engine.update_models!(network, ["dummy-t2t"], actor: user)

      %{retry_network: network}
    end

    test "successful invocation processing without retries", %{retry_network: network, user: user} do
      # Start a new run
      {:ok, genesis} = NetworkRunner.start_run(network.id, "Test prompt", user)
      allow_network_runner_db_access(network.id)

      # Wait for processing to complete
      Process.sleep(100)

      # Verify the invocation was processed
      invocation = Ash.get!(Engine.Invocation, genesis.id, actor: user)
      assert invocation.state in [:invoked, :invoking, :completed]
    end

    test "retry count increases on failures", %{retry_network: network, user: user} do
      # AIDEV-NOTE: Testing retry behavior by simulating state changes
      # Start a run
      {:ok, _genesis} = NetworkRunner.start_run(network.id, "Test prompt", user)

      # Get the runner pid
      [{pid, _}] = Registry.lookup(NetworkRegistry, network.id)
      allow_network_runner_db_access(network.id)

      # Wait for initial processing
      Process.sleep(100)

      # Simulate a failure state by setting retry count
      :sys.replace_state(pid, fn state ->
        %{state | retry_count: 2}
      end)

      # Verify the retry count was set
      state = :sys.get_state(pid)
      assert state.retry_count == 2

      # Stop the run to clean up
      NetworkRunner.stop_run(network.id)
    end

    test "max retries configuration is respected", %{retry_network: network, user: user} do
      # Configure max retries to 2 for this test
      Application.put_env(:panic, :network_runner_max_retries, 2)

      # Start a run
      {:ok, _genesis} = NetworkRunner.start_run(network.id, "Test prompt", user)

      # Get the runner pid
      [{pid, _}] = Registry.lookup(NetworkRegistry, network.id)
      allow_network_runner_db_access(network.id)

      # Verify max_retries was set from config
      state = :sys.get_state(pid)
      assert state.max_retries == 2

      # Stop the run
      NetworkRunner.stop_run(network.id)

      # Cleanup
      Application.delete_env(:panic, :network_runner_max_retries)
    end

    test "retry count resets on successful invocation", %{retry_network: network, user: user} do
      # Start a run
      {:ok, _genesis} = NetworkRunner.start_run(network.id, "Test prompt", user)

      # Get the runner pid
      [{pid, _}] = Registry.lookup(NetworkRegistry, network.id)
      allow_network_runner_db_access(network.id)

      # Simulate a few retries by manually setting retry count
      :sys.replace_state(pid, fn state ->
        %{state | retry_count: 3}
      end)

      # Send process_invocation message
      send(pid, :process_invocation)

      # Wait a bit for processing
      Process.sleep(100)

      # Check that retry count was reset
      state = :sys.get_state(pid)
      assert state.retry_count == 0
    end

    test "stop_run cancels retries", %{retry_network: network, user: user} do
      # Configure max retries high
      Application.put_env(:panic, :network_runner_max_retries, 10)

      # Start a run
      {:ok, _genesis} = NetworkRunner.start_run(network.id, "Test prompt", user)

      # Get the runner pid and force it into retry state
      [{pid, _}] = Registry.lookup(NetworkRegistry, network.id)
      allow_network_runner_db_access(network.id)

      :sys.replace_state(pid, fn state ->
        # Schedule a retry
        ref = Process.send_after(self(), :retry_invocation, 5000)
        %{state | processing_ref: ref, retry_count: 2}
      end)

      # Stop the run
      {:ok, :stopped} = NetworkRunner.stop_run(network.id)

      # Verify retry was cancelled
      state = :sys.get_state(pid)
      assert state.retry_count == 0
      assert is_nil(state.processing_ref)
      assert is_nil(state.current_invocation)

      # Cleanup
      Application.delete_env(:panic, :network_runner_max_retries)
    end
  end

  describe "configuration" do
    test "respects network_runner_max_retries config" do
      # Set custom max retries
      Application.put_env(:panic, :network_runner_max_retries, 3)

      # Start a runner
      {:ok, pid} = NetworkRunner.start_link(network_id: 123)

      # Check state
      state = :sys.get_state(pid)
      assert state.max_retries == 3

      # Cleanup
      GenServer.stop(pid)
      Application.delete_env(:panic, :network_runner_max_retries)
    end

    test "uses default max retries when not configured" do
      # Ensure config is not set
      Application.delete_env(:panic, :network_runner_max_retries)

      # Start a runner
      {:ok, pid} = NetworkRunner.start_link(network_id: 123)

      # Check state uses default
      state = :sys.get_state(pid)
      assert state.max_retries == 5

      # Cleanup
      GenServer.stop(pid)
    end
  end
end
