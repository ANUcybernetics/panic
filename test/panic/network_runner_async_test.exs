defmodule Panic.NetworkRunnerAsyncTest do
  @moduledoc """
  Tests for NetworkRunner using genuine async execution with PubSub-based
  synchronisation instead of sync mode workarounds.

  These tests prove that:
  - Shared sandbox mode gives spawned tasks DB access (no DatabasePatches needed)
  - PubSub broadcasts provide reliable synchronisation (no sync mode needed)
  - The NetworkRunner handles both success and failure paths correctly
  """
  use Panic.DataCase, async: false
  use Repatch.ExUnit

  alias Panic.Accounts.User
  alias Panic.Engine
  alias Panic.Engine.NetworkRunner
  alias Phoenix.Socket.Broadcast

  require Ash.Query

  @moduletag :capture_log

  setup do
    PanicWeb.Helpers.stop_all_network_runners()

    user = Ash.Generator.seed!(User)

    network =
      Engine.create_network!("Async Test Network", "Test network", actor: user)

    network =
      network
      |> Ash.Changeset.for_update(:update, %{lockout_seconds: 1}, actor: user)
      |> Ash.update!()

    network = Engine.update_models!(network, ["dummy-t2t"], actor: user)

    PanicWeb.Endpoint.subscribe("invocation:#{network.id}")

    on_exit(fn ->
      NetworkRunner.stop_run(network.id)
      PanicWeb.Helpers.stop_all_network_runners()
    end)

    {:ok, user: user, network: network}
  end

  describe "happy path (async)" do
    test "completes invocation and transitions to waiting", %{network: network} do
      {:ok, genesis} = NetworkRunner.start_run(network.id, "hello async")

      assert genesis.input == "hello async"
      assert genesis.sequence_number == 0

      genesis_id = genesis.id

      assert_receive %Broadcast{
                       event: "invoke",
                       payload: %{data: %{id: ^genesis_id, state: :completed}}
                     },
                     5_000

      NetworkRunner.stop_run(network.id)

      completed = Ash.get!(Engine.Invocation, genesis.id, authorize?: false)
      assert completed.state == :completed
      assert completed.output =~ "DUMMY_TEXT:"
    end
  end

  describe "failure handling (async)" do
    test "runner returns to idle when model invocation fails", %{network: network} do
      Repatch.patch(Panic.Platforms.Dummy, :invoke, [mode: :global], fn _model, _input, _token ->
        {:error, "simulated failure"}
      end)

      {:ok, genesis} = NetworkRunner.start_run(network.id, "this will fail")

      genesis_id = genesis.id

      assert_receive %Broadcast{
                       event: "mark_as_failed",
                       payload: %{data: %{id: ^genesis_id, state: :failed}}
                     },
                     5_000

      NetworkRunner.stop_run(network.id)
    end

    test "runner can start new run after failure", %{network: network} do
      call_count = :counters.new(1, [:atomics])

      Repatch.patch(Panic.Platforms.Dummy, :invoke, [mode: :global], fn model, input, token ->
        :counters.add(call_count, 1, 1)

        if :counters.get(call_count, 1) == 1 do
          {:error, "first call fails"}
        else
          Repatch.real(Panic.Platforms.Dummy.invoke(model, input, token))
        end
      end)

      {:ok, genesis} = NetworkRunner.start_run(network.id, "will fail first")

      genesis_id = genesis.id

      assert_receive %Broadcast{
                       event: "mark_as_failed",
                       payload: %{data: %{id: ^genesis_id, state: :failed}}
                     },
                     5_000

      Process.sleep(1100)

      {:ok, second_genesis} = NetworkRunner.start_run(network.id, "should succeed")

      second_id = second_genesis.id

      assert_receive %Broadcast{
                       event: "invoke",
                       payload: %{data: %{id: ^second_id, state: :completed}}
                     },
                     5_000

      NetworkRunner.stop_run(network.id)

      completed = Ash.get!(Engine.Invocation, second_id, authorize?: false)
      assert completed.state == :completed
      assert completed.output =~ "DUMMY_TEXT:"
    end
  end

  describe "multi-invocation cycling (async)" do
    test "second invocation completes after genesis", %{network: network} do
      {:ok, genesis} = NetworkRunner.start_run(network.id, "cycle test")

      genesis_id = genesis.id

      assert_receive %Broadcast{
                       event: "invoke",
                       payload: %{data: %{id: ^genesis_id, state: :completed}}
                     },
                     5_000

      assert_receive %Broadcast{
                       event: "invoke",
                       payload: %{data: %{sequence_number: 1, state: :completed}}
                     },
                     10_000

      NetworkRunner.stop_run(network.id)
    end
  end

  describe "multi-model network (async)" do
    test "chains text-to-image and image-to-text models", %{network: network, user: user} do
      PanicWeb.Endpoint.unsubscribe("invocation:#{network.id}")

      multi_network =
        Engine.create_network!("Multi Model Network", "Test multi-model", actor: user)

      multi_network =
        multi_network
        |> Ash.Changeset.for_update(:update, %{lockout_seconds: 1}, actor: user)
        |> Ash.update!()

      multi_network =
        Engine.update_models!(multi_network, ["dummy-t2i", "dummy-i2t"], actor: user)

      PanicWeb.Endpoint.subscribe("invocation:#{multi_network.id}")

      {:ok, genesis} = NetworkRunner.start_run(multi_network.id, "a beautiful sunset")

      genesis_id = genesis.id

      assert_receive %Broadcast{
                       event: "invoke",
                       payload: %{data: %{id: ^genesis_id, state: :completed, model: "dummy-t2i"}}
                     },
                     5_000

      assert_receive %Broadcast{
                       event: "invoke",
                       payload: %{data: %{sequence_number: 1, state: :completed, model: "dummy-i2t"}}
                     },
                     10_000

      NetworkRunner.stop_run(multi_network.id)

      genesis_result = Ash.get!(Engine.Invocation, genesis_id, authorize?: false)
      assert genesis_result.output =~ "dummy-images.test"
    end
  end

  describe "lockout enforcement (async)" do
    test "rejects run during lockout period", %{network: network} do
      {:ok, genesis} = NetworkRunner.start_run(network.id, "lockout test")

      genesis_id = genesis.id

      assert_receive %Broadcast{
                       event: "invoke",
                       payload: %{data: %{id: ^genesis_id, state: :completed}}
                     },
                     5_000

      {:lockout, returned} = NetworkRunner.start_run(network.id, "too soon")
      assert returned.id == genesis_id

      Process.sleep(1100)

      {:ok, second} = NetworkRunner.start_run(network.id, "after lockout")
      assert second.id != genesis_id
      assert second.input == "after lockout"

      NetworkRunner.stop_run(network.id)
    end
  end

  describe "stale message handling (async)" do
    test "ignores processing_completed after run is stopped", %{network: network} do
      {:ok, genesis} = NetworkRunner.start_run(network.id, "stale test")

      genesis_id = genesis.id

      assert_receive %Broadcast{
                       event: "invoke",
                       payload: %{data: %{id: ^genesis_id, state: :completed}}
                     },
                     5_000

      NetworkRunner.stop_run(network.id)

      [{pid, _}] = Registry.lookup(Panic.Engine.NetworkRegistry, network.id)

      send(pid, {:processing_completed, genesis})

      state = :sys.get_state(pid)
      assert state.genesis_invocation == nil
    end
  end

  describe "process restart resilience (async)" do
    test "new runner can start fresh run after previous runner dies", %{network: network} do
      {:ok, genesis} = NetworkRunner.start_run(network.id, "before crash")

      genesis_id = genesis.id

      assert_receive %Broadcast{
                       event: "invoke",
                       payload: %{data: %{id: ^genesis_id, state: :completed}}
                     },
                     5_000

      NetworkRunner.stop_run(network.id)

      [{pid, _}] = Registry.lookup(Panic.Engine.NetworkRegistry, network.id)
      DynamicSupervisor.terminate_child(Panic.Engine.NetworkSupervisor, pid)

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _}, 1_000

      Process.sleep(1100)

      {:ok, new_genesis} = NetworkRunner.start_run(network.id, "after restart")

      new_genesis_id = new_genesis.id
      assert new_genesis.input == "after restart"

      assert_receive %Broadcast{
                       event: "invoke",
                       payload: %{data: %{id: ^new_genesis_id, state: :completed}}
                     },
                     5_000

      NetworkRunner.stop_run(network.id)
    end
  end
end
