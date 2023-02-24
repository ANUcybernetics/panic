defmodule Panic.StateMachineTest do
  use Panic.DataCase, async: false

  @moduletag :fsm_tests

  ## requires async: false, above
  import Mock

  alias Panic.Predictions
  alias Panic.Runs.StateMachine
  import Panic.{AccountsFixtures, NetworksFixtures}

  setup_with_mocks([
    {Panic.Platforms, [:passthrough],
     [
       api_call: fn model, _input, _user ->
         Process.sleep(1000)
         {:ok, "result of API call to #{model}"}
       end
     ]}
  ]) do
    network = network_fixture()
    insert_api_tokens_from_env(network.user_id)

    ## start the FSM
    IO.puts("starting network #{network.id}")
    StateMachine.start_if_not_running(network)

    on_exit(fn ->
      IO.puts("shutting down network #{network.id}")
      ## to make sure all the API calls come in
      send_event_and_sleep(network.id, {:shut_down, nil}, 5_000)
      assert not StateMachine.alive?(network.id)

      check_network_invariants(network)
    end)

    {:ok, network: network}
  end

  describe "Run FSM" do
    test "golden path", %{network: network} do
      IO.puts("this test takes about 15s")
      assert [] = Predictions.list_predictions(network, 100)
      assert StateMachine.alive?(network.id)
      assert %Finitomata.State{current: :ready} = Finitomata.state(network.id)

      new_genesis_input(network.id, "ok, let's kick things off...", 10_000)
      assert %Finitomata.State{current: :uninterruptable} = Finitomata.state(network.id)

      ## this is a bit hard to test due to the async nature of things, but these
      ## things are _necessary_ for asserting that it's worked (not necessarily
      ## _sufficient_)
      check_network_invariants(network)

      # when startup time is 30s, network *should* still be in startup mode at this point
      send_event_and_sleep(network.id, {:reset, nil}, 1000)
      assert %Finitomata.State{current: :ready} = Finitomata.state(network.id)
    end

    test "receive new genesis prediction in uninterruptable period", %{network: network} do
      IO.puts("this test takes about 10s")
      assert [] = Predictions.list_predictions(network, 100)

      new_genesis_input(network.id, "tell me a story about a bunny")
      new_genesis_input(network.id, "a second input, hot on the heels of the first", 10_000)

      assert %Finitomata.State{current: :uninterruptable} = Finitomata.state(network.id)

      # check we only kept one first genesis input
      assert [first_genesis] =
               Predictions.list_predictions(network, 100)
               |> Enum.filter(fn p -> p.run_index == 0 end)

      assert first_genesis.input == "tell me a story about a bunny"

      check_network_invariants(network)
    end

    test "receive new genesis prediction after uninterruptable period ends", %{
      network: network
    } do
      IO.puts("this test takes about 60s")

      new_genesis_input(network.id, "tell me a story about a bunny")
      new_genesis_input(network.id, "a second input, hot on the heels of the first", 45_000)

      new_genesis_input(
        network.id,
        "a third input, after the uninterruptable period has ended",
        10_000
      )

      assert [first_genesis, third_genesis] =
               Predictions.list_predictions(network, 100)
               |> Enum.filter(fn p -> p.run_index == 0 end)

      assert first_genesis.input == "tell me a story about a bunny"
      assert third_genesis.input == "a third input, after the uninterruptable period has ended"

      check_network_invariants(network)
    end

    test "start run, then lock network, then receive a new input and resume", %{
      network: network
    } do
      IO.puts("this test takes about 30s")

      new_genesis_input(network.id, "tell me a story about a bunny", 5_000)
      send_event_and_sleep(network.id, {:lock, 10})
      new_genesis_input(network.id, "a second input, hot on the heels of the first", 15_000)
      assert %Finitomata.State{current: :ready} = Finitomata.state(network.id)
      new_genesis_input(network.id, "a third input", 10_000)

      assert [first_genesis, third_genesis] =
               Predictions.list_predictions(network, 100)
               |> Enum.filter(fn p -> p.run_index == 0 end)

      assert first_genesis.input == "tell me a story about a bunny"
      assert third_genesis.input == "a third input"

      check_network_invariants(network)
    end

    test "start run, then lock network, then 'manually' unlock ahead of time and resume", %{
      network: network
    } do
      IO.puts("this test takes about 35s")

      new_genesis_input(network.id, "tell me a story about a bunny", 5_000)
      send_event_and_sleep(network.id, {:lock, 10})
      new_genesis_input(network.id, "a second input, hot on the heels of the first", 1000)
      send_event_and_sleep(network.id, {:unlock, nil})
      new_genesis_input(network.id, "a third input", 10_000)

      assert [first_genesis, third_genesis] =
               Predictions.list_predictions(network, 100)
               |> Enum.filter(fn p -> p.run_index == 0 end)

      assert first_genesis.input == "tell me a story about a bunny"
      assert third_genesis.input == "a third input"

      check_network_invariants(network)
    end

    test "get_current_state/1 helper fn returns a valid state", %{network: network} do
      {:ok, transitions} = Finitomata.Mermaid.parse(StateMachine.fsm_description())

      assert StateMachine.get_current_state(network.id) in Finitomata.Transition.states(
               transitions
             )
    end
  end

  describe "static FSM checks" do
    test "transitions" do
      {:ok, transitions} = Finitomata.Mermaid.parse(StateMachine.fsm_description())
      assert Finitomata.Transition.allowed(transitions, :ready, :ready)
    end
  end

  # helper function for testing FSMs (because it takes a bit for them to finish transitioning)
  defp send_event_and_sleep(network_id, event, sleep_dur \\ 0) do
    Finitomata.transition(network_id, event)
    Process.sleep(sleep_dur)
  end

  # helper function for testing FSMs (because it takes a bit for them to finish transitioning)
  defp new_genesis_input(network_id, input, sleep_dur \\ 0) do
    Finitomata.transition(network_id, {:genesis_input, input})
    Process.sleep(sleep_dur)
  end

  ## these should be invariants for any network
  defp check_network_invariants(network) do
    predictions = Predictions.list_predictions(network, 100)

    assert Enum.chunk_by(predictions, fn p -> p.genesis_id end)
           |> Enum.each(&check_run_invariants/1)

    IO.puts(
      "successfully checked invariants on network #{network.id} (#{Enum.count(predictions)} predictions)"
    )
  end

  defp check_run_invariants([genesis | rest] = predictions) do
    assert genesis.run_index == 0

    assert Enum.map(predictions, fn p -> p.run_index end) ==
             Range.new(0, Enum.count(rest)) |> Enum.to_list()

    assert Enum.all?(rest, fn p -> p.genesis_id == genesis.id end)

    assert Enum.chunk_every(predictions, 2, 1, :discard)
           |> Enum.all?(fn [a, b] -> a.output == b.input end)
  end
end
