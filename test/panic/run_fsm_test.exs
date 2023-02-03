defmodule Panic.RunFSMTest do
  use Panic.DataCase

  import Panic.{AccountsFixtures, NetworksFixtures}

  describe "Run FSM" do
    setup [:create_network, :load_env_vars]

    test "single user, golden path", %{network: network} do
      fsm_name = "network:#{network.id}"

      Finitomata.start_fsm(Panic.Runs.RunFSM, fsm_name, %{network: network})
      assert Finitomata.alive?(fsm_name)
      assert %Finitomata.State{current: :waiting} = Finitomata.state(fsm_name)

      ## genesis input
      send_event_and_sleep(fsm_name, {:input, "ok, let's kick things off..."})
      assert %Finitomata.State{current: :running} = Finitomata.state(fsm_name)

      Process.sleep(10_000)

      IO.inspect(Finitomata.state(fsm_name))

      send_event_and_sleep(fsm_name, {:reset, nil})
      assert %Finitomata.State{current: :waiting} = Finitomata.state(fsm_name)

      send_event_and_sleep(fsm_name, {:shut_down, nil})
      ## here, at the end of all things
      assert not Finitomata.alive?(fsm_name)
    end
  end

  # helper function for testing FSMs (because it takes a bit for them to finish transitioning)
  defp send_event_and_sleep(fsm_name, event, sleep_dur \\ 200) do
    Finitomata.transition(fsm_name, event)
    Process.sleep(sleep_dur)
  end

  defp create_network(_context) do
    %{network: network_fixture()}
  end

  defp load_env_vars(%{network: network} = context) do
    insert_api_tokens_from_env(network.user_id)
    context
  end
end
