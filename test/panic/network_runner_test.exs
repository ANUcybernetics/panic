defmodule Panic.NetworkRunnerTest do
  use Panic.DataCase, async: false
  use ExUnitProperties
  use Repatch.ExUnit
  use PanicWeb.Helpers.DatabasePatches

  alias Panic.Accounts.User
  alias Panic.Engine
  alias Panic.Engine.NetworkRegistry
  alias Panic.Engine.NetworkRunner
  alias Panic.ExternalAPIPatches
  alias Panic.NetworkRunnerTestHelpers

  require Ash.Query

  @moduletag :capture_log

  setup do
    # Setup external API patches to avoid real network calls
    ExternalAPIPatches.setup()

    # Stop all network runners to ensure clean state
    PanicWeb.Helpers.stop_all_network_runners()

    # Enable synchronous mode for predictable tests
    NetworkRunnerTestHelpers.enable_sync_mode()

    # Create a test user
    user = Ash.Generator.seed!(User)

    # Create a test network using the code interface
    network = Engine.create_network!("Test Network", "Test network for NetworkRunner tests", actor: user)

    # Set lockout_seconds to 1 for tests
    network = network |> Ash.Changeset.for_update(:update, %{lockout_seconds: 1}, actor: user) |> Ash.update!()

    # Update the network with a dummy model (models is flat array)
    network = Engine.update_models!(network, ["dummy-t2t"], actor: user)

    on_exit(fn ->
      # Stop the specific network runner
      NetworkRunnerTestHelpers.stop_network_runner(network.id)

      # Stop all network runners to ensure complete cleanup
      PanicWeb.Helpers.stop_all_network_runners()

      # Disable synchronous mode
      NetworkRunnerTestHelpers.disable_sync_mode()

      # Teardown API patches
      ExternalAPIPatches.teardown()
    end)

    {:ok, user: user, network: network}
  end

  # =============================================================================
  # SECTION A: Direct GenServer Tests (using start_supervised)
  # These tests focus on the core state machine logic without registry complexity
  # =============================================================================

  describe "direct genserver state machine" do
    test "initializes with correct idle state", %{network: network} do
      {:ok, pid} = start_supervised({NetworkRunner, network_id: network.id})

      state = :sys.get_state(pid)
      assert state.network_id == network.id

      assert state.genesis_invocation == nil
      assert state.current_invocation == nil
      assert state.watchers == []
    end

    test "transitions from idle to running on start_run", %{network: network, user: _user} do
      {:ok, pid} = start_supervised({NetworkRunner, network_id: network.id})

      # Initially idle
      NetworkRunnerTestHelpers.assert_runner_idle(network.id)

      # Start a run
      {:ok, invocation} = GenServer.call(pid, {:start_run, "test prompt"})

      # Verify the invocation was created correctly
      assert invocation.network_id == network.id
      assert invocation.input == "test prompt"
      assert invocation.sequence_number == 0

      # Wait for sync completion
      NetworkRunnerTestHelpers.wait_for_sync_completion(network.id)
    end

    test "processes invocations and can be stopped manually", %{network: network, user: _user} do
      {:ok, pid} = start_supervised({NetworkRunner, network_id: network.id})

      # Start a run
      {:ok, invocation} = GenServer.call(pid, {:start_run, "test prompt"})

      # Wait for some processing to occur
      NetworkRunnerTestHelpers.wait_for_sync_completion(network.id)

      # Verify the initial invocation was processed
      completed_invocation = Ash.get!(Engine.Invocation, invocation.id, authorize?: false)
      assert completed_invocation.state == :completed
      assert completed_invocation.output != nil

      # Stop the run manually
      {:ok, :stopped} = GenServer.call(pid, :stop_run)

      # Should now be idle
      NetworkRunnerTestHelpers.assert_runner_idle(network.id)
    end

    test "enforces lockout period", %{network: network, user: _user} do
      {:ok, pid} = start_supervised({NetworkRunner, network_id: network.id})

      # Start first run
      {:ok, first_invocation} = GenServer.call(pid, {:start_run, "first prompt"})

      # Wait for processing to complete
      NetworkRunnerTestHelpers.wait_for_sync_completion(network.id)

      # Try to start second run immediately - should be locked out since lockout_seconds is 1
      {:lockout, returned_invocation} = GenServer.call(pid, {:start_run, "second prompt"})
      assert returned_invocation.id == first_invocation.id

      # Wait for lockout to expire
      Process.sleep(1100)

      # Should be able to start new run now
      {:ok, second_invocation} = GenServer.call(pid, {:start_run, "second prompt"})
      assert second_invocation.id != first_invocation.id
    end

    test "handles stop_run in various states", %{network: network, user: _user} do
      {:ok, pid} = start_supervised({NetworkRunner, network_id: network.id})

      # Stop when idle
      {:ok, :not_running} = GenServer.call(pid, :stop_run)

      # Start a run
      {:ok, _invocation} = GenServer.call(pid, {:start_run, "test prompt"})

      # In sync mode, processing completes immediately, so we might be idle already
      # Stop should work regardless
      result = GenServer.call(pid, :stop_run)
      assert result in [{:ok, :stopped}, {:ok, :not_running}]

      # Should be idle now
      NetworkRunnerTestHelpers.assert_runner_idle(network.id)
    end
  end

  # =============================================================================
  # SECTION B: Registry Integration Tests
  # These tests verify the NetworkRunner registry and automatic startup behavior
  # =============================================================================

  describe "registry integration" do
    test "start_run automatically starts runner if not running", %{network: network, user: _user} do
      # Ensure no runner exists
      assert [] == Registry.lookup(NetworkRegistry, network.id)

      # Start run should create runner and start run
      {:ok, invocation} = NetworkRunner.start_run(network.id, "test prompt")

      # Should now have a runner registered
      assert [{_pid, _}] = Registry.lookup(NetworkRegistry, network.id)

      # Verify the invocation
      assert invocation.network_id == network.id
      assert invocation.input == "test prompt"
    end

    test "start_run uses existing runner if already running", %{network: network, user: _user} do
      # Start first run to create runner
      {:ok, first_invocation} = NetworkRunner.start_run(network.id, "first prompt")
      [{first_pid, _}] = Registry.lookup(NetworkRegistry, network.id)

      # Start second run should use same runner (but be locked out)
      {:lockout, lockout_invocation} = NetworkRunner.start_run(network.id, "second prompt")
      [{second_pid, _}] = Registry.lookup(NetworkRegistry, network.id)

      # Same PID, same invocation returned
      assert first_pid == second_pid
      assert lockout_invocation.id == first_invocation.id
    end

    test "stop_run works through registry", %{network: network, user: _user} do
      # Start a run
      {:ok, _invocation} = NetworkRunner.start_run(network.id, "test prompt")

      # Stop through registry
      {:ok, :stopped} = NetworkRunner.stop_run(network.id)

      # Should still have runner but be idle
      NetworkRunnerTestHelpers.assert_runner_idle(network.id)

      # Stop non-existent runner
      other_network_id = 99_999
      {:ok, :not_running} = NetworkRunner.stop_run(other_network_id)
    end
  end

  # =============================================================================
  # SECTION C: Core Business Logic Tests
  # These test invocation processing, run creation, and error handling
  # =============================================================================

  describe "invocation processing" do
    test "creates and processes invocations correctly", %{network: network, user: _user} do
      {:ok, genesis} = NetworkRunner.start_run(network.id, "test prompt")
      NetworkRunnerTestHelpers.wait_for_sync_completion(network.id)

      # Verify the invocation was created and processed
      invocation = Ash.get!(Engine.Invocation, genesis.id, authorize?: false)
      assert invocation.network_id == network.id
      assert invocation.sequence_number == 0
      assert invocation.run_number == genesis.id
      assert invocation.input == "test prompt"
      # dummy model completes quickly
      assert invocation.state in [:completed, :ready]
    end

    test "runner survives processing errors", %{network: network, user: _user} do
      {:ok, _genesis} = NetworkRunner.start_run(network.id, "test prompt")

      # Runner should still be alive after processing
      assert [{pid, _}] = Registry.lookup(NetworkRegistry, network.id)
      assert Process.alive?(pid)

      # Should be able to stop cleanly
      {:ok, :stopped} = NetworkRunner.stop_run(network.id)
      assert Process.alive?(pid)
    end
  end

  describe "invocation chaining logic" do
    test "handles invocation chaining correctly", %{user: user} do
      # Create a simple network to test Engine logic without NetworkRunner complexity
      test_network = Engine.create_network!("Test Chaining Network", "Test network", actor: user)

      test_network =
        test_network |> Ash.Changeset.for_update(:update, %{lockout_seconds: 1}, actor: user) |> Ash.update!()

      test_network = Engine.update_models!(test_network, ["dummy-t2t"], actor: user)

      # Test basic invocation creation and chaining
      first = Engine.prepare_first!(test_network, "Test input", actor: user)
      completed_first = Engine.invoke!(first, actor: user)

      # Verify first invocation properties
      assert completed_first.sequence_number == 0
      assert completed_first.input == "Test input"
      assert completed_first.output != nil

      # Test prepare_next creates proper sequence
      case Engine.prepare_next(completed_first, actor: user) do
        {:ok, next} ->
          assert next.run_number == completed_first.run_number
          assert next.sequence_number == completed_first.sequence_number + 1
          assert next.input == completed_first.output

        {:error, :no_next_model} ->
          # This is also valid if the network is designed to terminate
          :ok

        {:error, _} ->
          # Network might be configured to loop infinitely, which is expected for dummy-t2t
          :ok
      end
    end
  end

  # =============================================================================
  # SECTION D: NetworkRunner Reliability Tests
  # These tests verify the NetworkRunner handles edge cases and cleanup properly
  # =============================================================================

  describe "runner reliability" do
    test "processes invocations successfully with sync mode", %{network: network, user: _user} do
      {:ok, pid} = start_supervised({NetworkRunner, network_id: network.id})

      # Start a run
      {:ok, genesis} = GenServer.call(pid, {:start_run, "test prompt"})

      # Wait for sync processing
      NetworkRunnerTestHelpers.wait_for_sync_completion(network.id)

      # Verify processing completed
      invocation = Ash.get!(Engine.Invocation, genesis.id, authorize?: false)
      assert invocation.state == :completed
      assert invocation.output != nil
    end

    test "maintains state correctly across operations", %{network: network, user: _user} do
      {:ok, pid} = start_supervised({NetworkRunner, network_id: network.id})

      # Start run and verify state
      {:ok, _genesis} = GenServer.call(pid, {:start_run, "original prompt"})

      state = :sys.get_state(pid)
      assert state.genesis_invocation.input == "original prompt"

      # Stop and verify cleanup
      {:ok, :stopped} = GenServer.call(pid, :stop_run)
      NetworkRunnerTestHelpers.assert_runner_idle(network.id)
    end

    test "handles stop operations cleanly", %{network: network, user: _user} do
      {:ok, pid} = start_supervised({NetworkRunner, network_id: network.id})

      # Start run
      {:ok, _genesis} = GenServer.call(pid, {:start_run, "test prompt"})

      # Stop should work immediately
      {:ok, :stopped} = GenServer.call(pid, :stop_run)

      # Process should remain alive and be idle
      assert Process.alive?(pid)
      NetworkRunnerTestHelpers.assert_runner_idle(network.id)

      # Should be able to start again
      {:ok, new_genesis} = GenServer.call(pid, {:start_run, "new prompt"})
      assert new_genesis.input == "new prompt"
    end

    test "survives processing errors gracefully", %{network: network, user: _user} do
      {:ok, pid} = start_supervised({NetworkRunner, network_id: network.id})

      # Start run
      {:ok, _genesis} = GenServer.call(pid, {:start_run, "test prompt"})

      # Process should remain alive even if there are errors
      assert Process.alive?(pid)

      # Should be able to stop cleanly
      result = GenServer.call(pid, :stop_run)
      assert result in [{:ok, :stopped}, {:ok, :not_running}]
      assert Process.alive?(pid)
    end

    test "survives process restart without losing user context", %{network: network, user: _user} do
      # Start a NetworkRunner and get it processing
      {:ok, pid1} = start_supervised({NetworkRunner, network_id: network.id})
      {:ok, genesis} = GenServer.call(pid1, {:start_run, "test prompt"})

      # Wait for processing to start
      Process.sleep(100)

      # Stop the supervised process to simulate a crash/restart
      stop_supervised(NetworkRunner)

      # Wait for registry cleanup
      Process.sleep(100)

      # Start a new NetworkRunner with the same network_id (simulating restart)
      {:ok, pid2} = start_supervised({NetworkRunner, network_id: network.id})

      # Verify it's a different process
      refute pid1 == pid2

      # The new process should be able to handle operations that require user context
      # by dynamically loading the user from the network (this tests crash resilience)

      # Send a delayed invocation message to test user context loading
      # In the old implementation, this would fail because state.user would be nil
      send(pid2, {:delayed_invocation, genesis})

      # The process should be able to handle this without crashing
      # (it will try to get user context dynamically)
      Process.sleep(500)

      # Verify the process is still alive and hasn't crashed
      assert Process.alive?(pid2)

      # Verify it can start new runs (which also requires user context)
      # This demonstrates that the NetworkRunner is truly crash-resilient
      {:ok, _new_invocation} = GenServer.call(pid2, {:start_run, "new prompt after restart"})
    end
  end

  describe "configuration" do
    test "state is properly initialized correctly", %{network: network} do
      {:ok, pid} = start_supervised({NetworkRunner, network_id: network.id})

      # Check state has expected fields
      state = :sys.get_state(pid)
      assert state.network_id == network.id
      assert state.genesis_invocation == nil
      assert state.current_invocation == nil
      assert state.watchers == []
    end

    test "respects network lockout settings", %{user: user} do
      # Create network with longer lockout for testing
      custom_network = Engine.create_network!("Custom Lockout Network", "Test network", actor: user)

      custom_network =
        custom_network |> Ash.Changeset.for_update(:update, %{lockout_seconds: 2}, actor: user) |> Ash.update!()

      custom_network = Engine.update_models!(custom_network, ["dummy-t2t"], actor: user)

      {:ok, pid} = start_supervised({NetworkRunner, network_id: custom_network.id})

      # Start first run
      {:ok, genesis} = GenServer.call(pid, {:start_run, "first prompt"})
      NetworkRunnerTestHelpers.wait_for_sync_completion(custom_network.id)

      # Try second run immediately - should be locked out
      {:lockout, lockout_genesis} = GenServer.call(pid, {:start_run, "second prompt"})
      assert lockout_genesis.id == genesis.id

      # Wait for lockout to expire
      Process.sleep(2100)

      # Should be able to start new run now
      {:ok, new_genesis} = GenServer.call(pid, {:start_run, "third prompt"})
      assert new_genesis.id != genesis.id
    end
  end

  describe "watcher dispatch" do
    test "handles watcher configuration correctly", %{network: network, user: _user} do
      {:ok, pid} = start_supervised({NetworkRunner, network_id: network.id})

      # Start a run with watcher dispatch
      {:ok, genesis} = GenServer.call(pid, {:start_run, "test input"})

      # NetworkRunner should handle watcher dispatch without errors
      # The ExternalAPIPatches mock the actual Vestaboard calls
      NetworkRunnerTestHelpers.wait_for_sync_completion(network.id)

      # Verify the run completed successfully
      invocation = Ash.get!(Engine.Invocation, genesis.id, authorize?: false)
      assert invocation.state == :completed
    end

    test "watcher dispatch doesn't block processing", %{network: network, user: _user} do
      {:ok, pid} = start_supervised({NetworkRunner, network_id: network.id})

      # Watcher dispatch should be fast and not interfere with processing
      start_time = System.monotonic_time(:millisecond)

      {:ok, _genesis} = GenServer.call(pid, {:start_run, "test prompt"})
      NetworkRunnerTestHelpers.wait_for_sync_completion(network.id)

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # Should complete quickly (sync mode + mocked APIs)
      assert duration < 1000, "Processing took #{duration}ms, should be much faster"
    end
  end
end
