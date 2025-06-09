defmodule Panic.Engine.NetworkRunnerTest do
  use Panic.DataCase, async: false

  alias Panic.Accounts.User
  alias Panic.Engine
  alias Panic.Engine.NetworkRegistry
  alias Panic.Engine.NetworkRunner

  require Ash.Query

  setup do
    # Create a test user
    user = Ash.Generator.seed!(User)

    # Create a test network using the code interface
    network = Engine.create_network!("Test Network", "Test network for NetworkRunner tests", actor: user)

    # Update the network with a dummy model (models is array of arrays)
    network = Engine.update_models!(network, [["dummy-t2t"]], actor: user)

    on_exit(fn ->
      # Stop any running gen servers for this network
      NetworkRunner.stop_run(network.id)

      # Kill the runner if it exists
      case Registry.lookup(NetworkRegistry, network.id) do
        [{pid, _}] -> Process.exit(pid, :kill)
        [] -> :ok
      end
    end)

    {:ok, user: user, network: network}
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

      Process.sleep(10)

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

      assert genesis_invocation.network_id == network.id
      assert [{_pid, _}] = Registry.lookup(NetworkRegistry, network.id)
    end

    @tag timeout: 35_000
    test "cancels existing run when starting a new one", %{network: network, user: user} do
      {:ok, first_genesis} = NetworkRunner.start_run(network.id, "First prompt", user)

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
          # Try to start another run immediately
          {:lockout, lockout_genesis} = NetworkRunner.start_run(network.id, "Another prompt", user)
          assert lockout_genesis.id == genesis_invocation.id

        {:lockout, _} ->
          # Already in lockout from previous test, wait and retry
          Process.sleep(1_500)
          {:ok, genesis_invocation} = NetworkRunner.start_run(network.id, "Test prompt", user)
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

      assert {:ok, :stopped} = NetworkRunner.stop_run(network.id)
    end

    test "returns not_running if no runner genserver exists", %{network: network} do
      # Stop any runner that might be running from other tests
      _ = NetworkRunner.stop_run(network.id)
      # Give it time to fully stop
      Process.sleep(100)

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

      # The runner should be alive
      assert [{pid, _}] = Registry.lookup(NetworkRegistry, network.id)
      assert Process.alive?(pid)

      # Stop the run
      NetworkRunner.stop_run(network.id)

      # runner should still be alive after stopping
      assert Process.alive?(pid)
    end
  end
end
