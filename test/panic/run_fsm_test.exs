defmodule Panic.RunFSMTest do
  use Panic.DataCase

  import Panic.{AccountsFixtures, PredictionsFixtures, NetworksFixtures}

  # helper function for testing FSMs (because it takes a bit for them to finish transitioning)
  defp send_event_and_sleep(fsm_name, event, sleep_dur \\ 200) do
    Finitomata.transition(fsm_name, event)
    Process.sleep(sleep_dur)
  end

  describe "Run FSM" do
    test "golden path" do
      user = user_fixture()
      network = network_fixture(%{user_id: user.id})
      fsm_name = "network:#{network.id}"

      Finitomata.start_fsm(Panic.Runs.RunFSM, fsm_name, %{user: user, network: network})
      assert Finitomata.alive?(fsm_name)
      assert %Finitomata.State{current: :waiting} = Finitomata.state(fsm_name)

      genesis = prediction_fixture()
      send_event_and_sleep(fsm_name, {:prediction, genesis})
      assert %Finitomata.State{current: :running} = Finitomata.state(fsm_name)

      Process.sleep(10_000)
      ## here, at the end of all things
      assert not Finitomata.alive?(fsm_name)
    end
  end
end
