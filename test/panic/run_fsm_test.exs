defmodule Panic.RunFSMTest do
  use Panic.DataCase

  alias Panic.Predictions
  import Panic.{AccountsFixtures, NetworksFixtures}

  describe "Run FSM" do
    setup [:create_network, :load_env_vars, :start_fsm]

    test "golden path", %{network: network} do
      assert Finitomata.alive?(network.id)
      assert %Finitomata.State{current: :waiting} = Finitomata.state(network.id)

      ## genesis input
      send_event_and_sleep(network.id, {:input, "ok, let's kick things off..."})
      assert %Finitomata.State{current: :running} = Finitomata.state(network.id)

      seconds = 10
      IO.puts("about to run the FSM for #{seconds}s, please be patient...")
      Process.sleep(seconds * 1000)

      ## this is a bit hard to test due to the async nature of things, but these
      ## things are _necessary_ for asserting that it's worked (not necessarily
      ## _sufficient_)
      check_run_invariants(network)

      send_event_and_sleep(network.id, {:reset, nil})
      assert %Finitomata.State{current: :waiting} = Finitomata.state(network.id)
    end

    test "receive new input in initial lockout period", %{network: network} do
      # genesis input
      first_input = "tell me a story about a bunny"
      send_event_and_sleep(network.id, {:input, first_input})

      assert %Finitomata.State{current: :running} = Finitomata.state(network.id)

      second_input = "a second input, hot on the heels of the first"

      seconds = 10
      IO.puts("about to run the FSM for #{seconds}s, please be patient...")
      send_event_and_sleep(network.id, {:input, second_input})
      Process.sleep(seconds * 1000)

      # check we only got one genesis input (because the second input came during the lockout period)
      assert [genesis] =
               Predictions.list_predictions(network) |> Enum.filter(fn p -> p.run_index == 0 end)

      assert genesis.input == first_input

      ## this is a bit hard to test due to the async nature of things, but these
      ## things are _necessary_ for asserting that it's worked (not necessarily
      ## _sufficient_)
      check_run_invariants(network)
    end
  end

  # helper function for testing FSMs (because it takes a bit for them to finish transitioning)
  defp send_event_and_sleep(network_id, event, sleep_dur \\ 200) do
    Finitomata.transition(network_id, event)
    Process.sleep(sleep_dur)
  end

  defp create_network(_context) do
    %{network: network_fixture()}
  end

  defp load_env_vars(%{network: network} = context) do
    insert_api_tokens_from_env(network.user_id)
    context
  end

  defp start_fsm(%{network: network} = context) do
    Finitomata.start_fsm(Panic.Runs.RunFSM, network.id, %{network: network})

    on_exit(fn ->
      IO.puts("shutting down network #{network.id}")
      send_event_and_sleep(network.id, {:shut_down, nil})
      assert not Finitomata.alive?(network.id)
    end)

    context
  end

  defp check_run_invariants(network) do
    predictions = Predictions.list_predictions(network)
    [genesis | rest] = predictions
    assert genesis.run_index == 0

    assert Enum.map(predictions, & &1.run_index) ==
             Range.new(0, Enum.count(rest)) |> Enum.to_list()

    assert Enum.all?(rest, fn p -> p.genesis_id == genesis.id end)

    assert Enum.chunk_every(predictions, 2, 1, :discard)
           |> Enum.all?(fn [a, b] -> a.output == b.input end)

    IO.puts("successfully checked run invariants on #{Enum.count(predictions)} predictions")
  end
end
