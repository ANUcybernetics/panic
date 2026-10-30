defmodule Panic.Engine.RunTest do
  @moduledoc """
  End-to-end tests of a run: starting it, each invocation leading to the next,
  the lockout, stopping, failure, and the listeners that drive Vestaboards and
  archiving. Jobs run when a test drains their queue (see
  `Panic.EngineHelpers`).
  """
  use Panic.DataCase, async: false
  use Repatch.ExUnit

  import Ash.Signals.Test
  import Panic.EngineHelpers

  alias Panic.Engine
  alias Panic.Engine.Errors.RunLocked
  alias Panic.Engine.Invocation
  alias Panic.Engine.Network
  alias Panic.Engine.Signals
  alias Panic.Platforms.Dummy
  alias Panic.Platforms.Vestaboard
  alias Panic.Watcher.Installation

  require Ash.Query

  @moduletag :capture_log

  setup do
    user = Panic.Fixtures.user()
    Panic.Fixtures.vestaboard_credentials()

    network =
      "Run test network"
      |> Engine.create_network!("for engine tests", actor: user)
      |> Ash.Changeset.for_update(:update, %{lockout_seconds: 0}, actor: user)
      |> Ash.update!()
      |> Engine.update_models!(["dummy-t2t", "dummy-t2t"], actor: user)

    {:ok, user: user, network: network}
  end

  defp invocations(network) do
    Invocation
    |> Ash.Query.filter(network_id == ^network.id)
    |> Ash.Query.sort(id: :asc)
    |> Ash.read!(authorize?: false)
  end

  defp reload(record), do: Ash.reload!(record, authorize?: false)

  describe "starting a run" do
    test "creates the genesis invocation and records the run on the network", %{
      user: user,
      network: network
    } do
      genesis =
        assert_emits_signal(Signals, :run_started, %{input: "hello"}, fn ->
          Engine.start_run!(network, "hello", actor: user)
        end)

      assert %{sequence_number: 0, state: :ready, model: "dummy-t2t"} = genesis
      assert genesis.run_number == genesis.id

      network = reload(network)
      assert network.current_run_number == genesis.id
      assert network.run_started_at == genesis.inserted_at
    end

    test "rejects a run with no models", %{user: user} do
      network = Engine.create_network!("Empty", "no models", actor: user)
      assert {:error, _} = Engine.start_run(network, "hello", actor: user)
    end
  end

  describe "a running network" do
    test "each completed invocation feeds the next model", %{user: user, network: network} do
      genesis = Engine.start_run!(network, "hello", actor: user)

      assert %{success: 1} = run_next_invocation()
      genesis = reload(genesis)
      assert genesis.state == :completed
      assert genesis.output =~ "DUMMY_TEXT"

      assert [_, next] = invocations(network)
      assert %{sequence_number: 1, state: :ready, input: input, run_number: run} = next
      assert input == genesis.output
      assert run == genesis.run_number

      assert %{success: 1} = run_next_invocation()
      assert [_, %{state: :completed}, %{sequence_number: 2}] = invocations(network)
    end

    test "the next invocation starts after the backoff, and holds its output while a Vestaboard flips",
         %{user: user, network: network} do
      Engine.start_run!(network, "hello", actor: user)
      run_next_invocation()
      assert [_, next] = invocations(network)

      assert_in_delta DateTime.diff(next.invoke_after, DateTime.utc_now(), :millisecond),
                      1_000,
                      500

      assert next.hold_until == nil

      create_installation(
        user,
        network,
        [vestaboard("board-1", stride: 2, offset: 1, name: :panic_1)],
        vestaboard_hold_seconds: 12
      )

      run_next_invocation()
      assert [_, _, held] = invocations(network)

      assert_in_delta DateTime.diff(held.invoke_after, DateTime.utc_now(), :millisecond),
                      1_000,
                      500

      assert_in_delta DateTime.diff(held.hold_until, DateTime.utc_now(), :millisecond),
                      12_000,
                      500
    end

    test "a starting run invokes at once but holds its output for initial-prompt Vestaboards",
         %{user: user, network: network} do
      create_installation(
        user,
        network,
        [vestaboard("board-1", stride: 2, offset: 0, name: :panic_1, initial_prompt: true)],
        vestaboard_hold_seconds: 1
      )

      genesis = Engine.start_run!(network, "hello", actor: user)

      assert_in_delta DateTime.diff(genesis.invoke_after, genesis.inserted_at, :millisecond),
                      0,
                      100

      assert_in_delta DateTime.diff(genesis.hold_until, genesis.inserted_at, :millisecond),
                      1_000,
                      100

      run_next_invocation()
      genesis = reload(genesis)
      assert genesis.state == :completed
      assert DateTime.compare(genesis.updated_at, genesis.hold_until) != :lt
    end
  end

  describe "footprint" do
    test "each invocation records its model's usage and estimated footprint, which the run totals",
         %{user: user, network: network} do
      Repatch.patch(Dummy, :invoke, fn model, input, token ->
        {:ok, output, _usage} = Repatch.real(Dummy.invoke(model, input, token))

        {:ok, output, %{"platform" => "replicate", "path" => "krea/krea-3", "image_output_count" => 1}}
      end)

      genesis = Engine.start_run!(network, "hello", actor: user)
      assert %{success: 1} = run_next_invocation()
      assert %{success: 1} = run_next_invocation()

      assert [first, second, _next] = invocations(network)

      for invocation <- [first, second] do
        assert [%{"path" => "krea/krea-3"}] = invocation.metadata["usage"]
        assert_in_delta invocation.cost_usd, 0.03, 1.0e-9
        assert_in_delta invocation.energy_wh, 1.0, 1.0e-9
      end

      assert %{cost_usd: cost, energy_wh: energy} = Engine.run_footprint!(genesis.run_number)
      assert_in_delta cost, 0.06, 1.0e-9
      assert_in_delta energy, 2.0, 1.0e-9
    end
  end

  describe "lockout" do
    test "a second run within the lockout is rejected", %{user: user, network: network} do
      network =
        network
        |> Ash.Changeset.for_update(:update, %{lockout_seconds: 30}, actor: user)
        |> Ash.update!()

      Engine.start_run!(network, "first", actor: user)

      assert {:error, %Ash.Error.Invalid{errors: [%RunLocked{retry_at: retry_at}]}} =
               Engine.start_run(network, "second", actor: user)

      assert DateTime.after?(retry_at, DateTime.utc_now())
    end

    test "a run after the lockout replaces the current one", %{user: user, network: network} do
      first = Engine.start_run!(network, "first", actor: user)
      second = Engine.start_run!(network, "second", actor: user)

      assert reload(network).current_run_number == second.run_number

      # the first run's job no longer applies, the second's runs
      assert %{cancelled: 1} = run_next_invocation()
      assert reload(first).state == :ready
      assert %{success: 1} = run_next_invocation()
      assert reload(second).state == :completed
    end
  end

  describe "stopping a run" do
    test "cancels the pending invocation and idles the network", %{user: user, network: network} do
      genesis = Engine.start_run!(network, "hello", actor: user)
      network = Engine.stop_run!(reload(network), actor: user)

      assert network.current_run_number == nil
      assert %{cancelled: 1} = run_next_invocation()
      assert reload(genesis).state == :ready
    end

    test "an invocation that completes after the stop doesn't continue the run", %{
      user: user,
      network: network
    } do
      genesis = Engine.start_run!(network, "hello", actor: user)

      # stop the run while the model is being called
      Repatch.patch(Dummy, :invoke, fn model, input, token ->
        Engine.stop_run!(reload(network), actor: user)
        Repatch.real(Dummy.invoke(model, input, token))
      end)

      refute_emits_signal(Signals, :invocation_completed, %{}, fn ->
        assert %{success: 1} = run_next_invocation()
      end)

      assert reload(genesis).state == :completed
      assert [_] = invocations(network)
    end
  end

  describe "a failing model" do
    test "fails the invocation and ends the run", %{user: user, network: network} do
      Repatch.patch(Dummy, :invoke, fn _model, _input, _token -> {:error, "simulated failure"} end)

      genesis = Engine.start_run!(network, "hello", actor: user)
      assert %{success: 1} = run_next_invocation()

      genesis = reload(genesis)
      assert genesis.state == :failed
      assert genesis.metadata["error"] =~ "simulated failure"
      assert reload(network).current_run_number == nil
      assert [_] = invocations(network)
    end

    test "that refuses its input is retried with a safe input and the run carries on",
         %{user: user, network: network} do
      safe = Panic.Engine.Changes.InvokeModel.safe_input(:text)

      Repatch.patch(Dummy, :invoke, fn model, input, token ->
        if input == safe,
          do: Repatch.real(Dummy.invoke(model, input, token)),
          else: {:error, "Blocked by content policy (violence)"}
      end)

      genesis = Engine.start_run!(network, "something a filter dislikes", actor: user)
      assert %{success: 1} = run_next_invocation()

      genesis = reload(genesis)
      assert genesis.state == :completed
      assert genesis.metadata["error_before_safe_retry"] =~ "content policy"
      assert reload(network).current_run_number == genesis.run_number
      assert [_, _] = invocations(network)
    end

    test "a new run can start after a failure", %{user: user, network: network} do
      Repatch.patch(Dummy, :invoke, fn _model, _input, _token -> {:error, "simulated failure"} end)

      Engine.start_run!(network, "fails", actor: user)
      run_next_invocation()
      Repatch.restore(Dummy, :invoke, 3)

      second = Engine.start_run!(reload(network), "works", actor: user)
      assert %{success: 1} = run_next_invocation()
      assert reload(second).state == :completed
    end
  end

  describe "Vestaboards" do
    setup %{user: user, network: network} do
      test_pid = self()

      Repatch.patch(Vestaboard, :send_text, fn text, _token, board_name ->
        send(test_pid, {:vestaboard, board_name, text})
        {:ok, "id"}
      end)

      create_installation(user, network, [
        vestaboard("board-1", stride: 2, offset: 0, name: :panic_1, initial_prompt: true),
        vestaboard("board-2", stride: 2, offset: 1, name: :panic_2, initial_prompt: true)
      ])

      :ok
    end

    test "every initial-prompt board shows the prompt when a run starts", %{
      user: user,
      network: network
    } do
      Engine.start_run!(network, "hello boards", actor: user)
      drain_vestaboards()

      assert_received {:vestaboard, "panic_1", "hello boards"}
      assert_received {:vestaboard, "panic_2", "hello boards"}
    end

    test "each output goes to the board its sequence number lands on", %{
      user: user,
      network: network
    } do
      Engine.start_run!(network, "hello boards", actor: user)
      drain_vestaboards()
      assert_received {:vestaboard, "panic_1", "hello boards"}
      assert_received {:vestaboard, "panic_2", "hello boards"}
      run_next_invocation()
      run_next_invocation()
      drain_vestaboards()

      [genesis, second | _] = invocations(network)
      assert_received {:vestaboard, "panic_1", output} when output == genesis.output
      assert_received {:vestaboard, "panic_2", output} when output == second.output
      refute_received {:vestaboard, _, _}
    end
  end

  describe "archiving" do
    setup do
      # Repatch.ExUnit resets patches per test, so reapply the global archiver ones
      Panic.Test.ArchiverPatches.apply_patches()
    end

    test "an image output and the next input point at the archived copy", %{
      user: user,
      network: network
    } do
      network = Engine.update_models!(network, ["dummy-t2i", "dummy-i2t"], actor: user)

      Engine.start_run!(network, "a picture", actor: user)
      run_next_invocation()
      assert %{success: 1} = drain_archiver()

      assert [genesis, next] = invocations(network)
      assert genesis.output == "https://dummy-s3-url.com/test-file.webp"
      assert next.input == genesis.output
    end

    test "a text output isn't archived", %{user: user, network: network} do
      Engine.start_run!(network, "some words", actor: user)
      run_next_invocation()
      drain_archiver()

      assert [genesis, _] = invocations(network)
      assert genesis.output =~ "DUMMY_TEXT"
    end
  end

  describe "admin" do
    test "list_running_networks only includes networks with a current run", %{
      user: user,
      network: network
    } do
      assert [] = Engine.list_running_networks!(authorize?: false)
      Engine.start_run!(network, "hello", actor: user)
      assert [%Network{id: id}] = Engine.list_running_networks!(authorize?: false)
      assert id == network.id
    end
  end

  # the hold defaults to zero so runs with boards don't wait in tests
  defp create_installation(user, network, watchers, opts \\ []) do
    Installation
    |> Ash.Changeset.for_create(
      :create,
      %{
        name: "Boards",
        network_id: network.id,
        watchers: watchers,
        vestaboard_hold_seconds: Keyword.get(opts, :vestaboard_hold_seconds, 0)
      },
      actor: user
    )
    |> Ash.create!()
  end

  defp vestaboard(watcher_name, opts) do
    %{
      type: :vestaboard,
      name: watcher_name,
      stride: Keyword.fetch!(opts, :stride),
      offset: Keyword.fetch!(opts, :offset),
      vestaboard_name: Keyword.fetch!(opts, :name),
      initial_prompt: Keyword.get(opts, :initial_prompt, false)
    }
  end
end
