defmodule Panic.StateMachineTest do
  use Panic.DataCase, async: false

  @moduletag :fsm_tests

  ## requires async: false, above
  import Mock

  alias Panic.Accounts
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

    {:ok, network: network, tokens: Accounts.get_api_token_map(network.user_id)}
  end

  describe "Run FSM" do
    test "golden path", %{network: network, tokens: tokens} do
      IO.puts("this test takes about 15s")
      assert [] = Predictions.list_predictions(network, 100)
      assert StateMachine.alive?(network.id)
      assert %Finitomata.State{current: :waiting} = Finitomata.state(network.id)

      ## genesis input
      {:ok, genesis_prediction} =
        Predictions.create_prediction("ok, let's kick things off...", network, tokens)

      send_event_and_sleep(network.id, {:new_prediction, genesis_prediction}, 10_000)
      assert %Finitomata.State{current: :running_startup} = Finitomata.state(network.id)

      ## this is a bit hard to test due to the async nature of things, but these
      ## things are _necessary_ for asserting that it's worked (not necessarily
      ## _sufficient_)
      check_network_invariants(network)

      # when startup time is 30s, network *should* still be in startup mode at this point
      send_event_and_sleep(network.id, {:reset, nil}, 1000)
      assert %Finitomata.State{current: :waiting} = Finitomata.state(network.id)
    end

    test "receive new genesis prediction in lockout period", %{network: network, tokens: tokens} do
      IO.puts("this test takes about 10s")
      assert [] = Predictions.list_predictions(network, 100)
      # genesis input
      {:ok, first_genesis_prediction} =
        Predictions.create_prediction(
          "tell me a story about a bunny",
          network,
          tokens
        )

      {:ok, second_genesis_prediction} =
        Predictions.create_prediction(
          "a second input, hot on the heels of the first",
          network,
          tokens
        )

      send_event_and_sleep(network.id, {:new_prediction, first_genesis_prediction}, 0)
      send_event_and_sleep(network.id, {:new_prediction, second_genesis_prediction}, 10_000)
      assert %Finitomata.State{current: :running_startup} = Finitomata.state(network.id)

      # check we only kept the first genesis input
      assert [first_genesis] =
               Predictions.list_predictions(network, first_genesis_prediction.id)
               |> Enum.filter(fn p -> p.run_index == 0 end)

      assert first_genesis.input == first_genesis_prediction.input
      assert [] = Predictions.list_predictions_in_run(network, second_genesis_prediction.id)

      # check we didn't keep any of the runs from the second genesis prediction
      assert [] = Predictions.list_predictions_in_run(network, second_genesis_prediction.id)

      check_network_invariants(network)
    end

    test "receive new genesis prediction after lockout period ends", %{
      network: network,
      tokens: tokens
    } do
      IO.puts("this test takes about 60s")

      # genesis input
      {:ok, first_genesis_prediction} =
        Predictions.create_prediction(
          "tell me a story about a bunny",
          network,
          tokens
        )

      {:ok, second_genesis_prediction} =
        Predictions.create_prediction(
          "a second input, hot on the heels of the first",
          network,
          tokens
        )

      send_event_and_sleep(network.id, {:new_prediction, first_genesis_prediction}, 45_000)
      send_event_and_sleep(network.id, {:new_prediction, second_genesis_prediction}, 10_000)

      # check there's at least one prediction in each run two new runs
      assert [first | _] = Predictions.list_predictions(network, first_genesis_prediction.id)
      assert Panic.Repo.preload(first, [:network]) == first_genesis_prediction

      assert [second | _] =
               Predictions.list_predictions_in_run(network, second_genesis_prediction.id)

      assert Panic.Repo.preload(second, [:network]) == second_genesis_prediction

      check_network_invariants(network)
    end

    test "start run, then lock network, then receive a new input and resume", %{
      network: network,
      tokens: tokens
    } do
      IO.puts("this test takes about 35s")
      # genesis input
      {:ok, p1} =
        Predictions.create_prediction(
          "tell me a story about a bunny",
          network,
          tokens
        )

      {:ok, p2} =
        Predictions.create_prediction(
          "a second input, hot on the heels of the first",
          network,
          tokens
        )

      {:ok, p3} =
        Predictions.create_prediction(
          "a second input, hot on the heels of the first",
          network,
          tokens
        )

      send_event_and_sleep(network.id, {:new_prediction, p1}, 200)
      send_event_and_sleep(network.id, {:lock, 20}, 200)
      send_event_and_sleep(network.id, {:new_prediction, p2}, 30_000)
      send_event_and_sleep(network.id, {:new_prediction, p3}, 10_000)

      # check we only kept the first genesis input
      assert Predictions.get_prediction!(p1.id)
      assert_raise Ecto.NoResultsError, fn -> Predictions.get_prediction!(p2.id) end
      assert Predictions.get_prediction!(p3.id)

      check_network_invariants(network)
    end

    test "start run, then lock network, then 'manually' unlock ahead of time and resume", %{
      network: network,
      tokens: tokens
    } do
      IO.puts("this test takes about 35s")
      # genesis input
      {:ok, p1} =
        Predictions.create_prediction(
          "tell me a story about a bunny",
          network,
          tokens
        )

      {:ok, p2} =
        Predictions.create_prediction(
          "a second input, hot on the heels of the first",
          network,
          tokens
        )

      {:ok, p3} =
        Predictions.create_prediction(
          "a third input, hot on the heels of the first",
          network,
          tokens
        )

      send_event_and_sleep(network.id, {:new_prediction, p1}, 200)
      send_event_and_sleep(network.id, {:lock, 20}, 200)
      send_event_and_sleep(network.id, {:new_prediction, p2}, 1000)
      send_event_and_sleep(network.id, {:unlock, nil}, 200)
      send_event_and_sleep(network.id, {:new_prediction, p3}, 10_000)

      # check we only kept the first genesis input
      assert Predictions.get_prediction!(p1.id)
      assert_raise Ecto.NoResultsError, fn -> Predictions.get_prediction!(p2.id) end
      assert Predictions.get_prediction!(p3.id)

      check_network_invariants(network)
    end

    test "current_state/1 helper fn returns a valid state", %{network: network} do
      {:ok, transitions} = Finitomata.Mermaid.parse(StateMachine.fsm_description())
      assert StateMachine.current_state(network.id) in Finitomata.Transition.states(transitions)
    end
  end

  describe "static FSM checks" do
    test "transitions" do
      {:ok, transitions} = Finitomata.Mermaid.parse(StateMachine.fsm_description())
      assert Finitomata.Transition.allowed(transitions, :waiting, :waiting)
    end
  end

  # helper function for testing FSMs (because it takes a bit for them to finish transitioning)
  defp send_event_and_sleep(network_id, event, sleep_dur) do
    Finitomata.transition(network_id, event)
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
