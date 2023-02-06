defmodule Panic.RunFSMTest do
  use Panic.DataCase, async: false
  ## requires async: false, above
  import Mock

  alias Panic.Predictions
  import Panic.{AccountsFixtures, NetworksFixtures}

  # when we need to let the thing run, how long to let it run for?
  @fsm_runtime 10_000

  setup_with_mocks([
    {Panic.Platforms, [],
     [
       api_call: fn model, _input, _user ->
         Process.sleep(1000)
         "result of API call to #{model}"
       end
     ]}
  ]) do
    network = network_fixture()
    insert_api_tokens_from_env(network.user_id)

    ## start the FSM
    IO.puts("starting network #{network.id}")
    Finitomata.start_fsm(Panic.Runs.RunFSM, network.id, %{network: network})

    on_exit(fn ->
      IO.puts("shutting down network #{network.id}")
      ## to make sure all the API calls come in
      send_event_and_sleep(network.id, {:shut_down, nil}, 5_000)
      assert not Finitomata.alive?(network.id)

      check_network_invariants(network)
    end)

    {:ok, network: network}
  end

  describe "Run FSM" do
    test "golden path", %{network: network} do
      assert [] = Predictions.list_predictions(network)
      assert Finitomata.alive?(network.id)
      assert %Finitomata.State{current: :waiting} = Finitomata.state(network.id)

      ## genesis input
      {:ok, genesis_prediction} =
        Predictions.create_genesis_prediction("ok, let's kick things off...", network)

      send_event_and_sleep(network.id, {:new_prediction, genesis_prediction})
      assert %Finitomata.State{current: :running} = Finitomata.state(network.id)

      Process.sleep(@fsm_runtime)

      ## this is a bit hard to test due to the async nature of things, but these
      ## things are _necessary_ for asserting that it's worked (not necessarily
      ## _sufficient_)
      check_network_invariants(network)

      send_event_and_sleep(network.id, {:reset, nil})
      assert %Finitomata.State{current: :waiting} = Finitomata.state(network.id)
    end

    test "receive new genesis prediction in lockout period", %{network: network} do
      assert [] = Predictions.list_predictions(network)
      # genesis input
      {:ok, first_genesis_prediction} =
        Predictions.create_genesis_prediction("tell me a story about a bunny", network)

      {:ok, second_genesis_prediction} =
        Predictions.create_genesis_prediction(
          "a second input, hot on the heels of the first",
          network
        )

      send_event_and_sleep(network.id, {:new_prediction, first_genesis_prediction}, 0)
      send_event_and_sleep(network.id, {:new_prediction, second_genesis_prediction})

      Process.sleep(@fsm_runtime)

      # check we only kept the first genesis input
      assert [first_genesis] =
               Predictions.list_predictions(network, first_genesis_prediction.id)
               |> Enum.filter(fn p -> p.run_index == 0 end)

      assert first_genesis.input == first_genesis_prediction.input
      assert [] = Predictions.list_predictions(network, second_genesis_prediction.id)

      # check we didn't keep any of the runs from the second genesis prediction
      assert [] = Predictions.list_predictions(network, second_genesis_prediction.id)

      check_network_invariants(network)
    end
  end

  # helper function for testing FSMs (because it takes a bit for them to finish transitioning)
  defp send_event_and_sleep(network_id, event, sleep_dur \\ 200) do
    Finitomata.transition(network_id, event)
    Process.sleep(sleep_dur)
  end

  ## these should be invariants for any network
  defp check_network_invariants(network) do
    predictions = Predictions.list_predictions(network)

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
