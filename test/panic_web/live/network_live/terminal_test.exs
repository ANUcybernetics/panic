defmodule PanicWeb.NetworkLive.TerminalTest do
  use PanicWeb.ConnCase, async: false

  import Panic.Fixtures

  alias Panic.Engine.Network
  alias PanicWeb.TerminalAuth

  describe "anonymous user with QR code token" do
    setup do
      PanicWeb.Helpers.stop_all_network_runners()

      user = user()

      {:ok, network} =
        Network
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Test Network",
            lockout_seconds: 0
          },
          actor: user
        )
        |> Ash.create()

      {:ok, network} =
        network
        |> Ash.Changeset.for_update(
          :update_models,
          %{
            models: ["dummy-t2t"]
          },
          actor: user
        )
        |> Ash.update()

      token = TerminalAuth.generate_token(network.id)

      %{network: network, user: user, token: token}
    end

    test "can access terminal with valid token and start run successfully", %{
      conn: conn,
      network: network,
      token: token,
      user: user
    } do
      conn
      |> visit("/networks/#{network.id}/terminal?token=#{token}")
      |> assert_has("[phx-submit=\"start-run\"]")
      |> fill_in("Prompt", with: "Hello world")
      |> submit()

      Process.sleep(200)

      invocations = Ash.read!(Panic.Engine.Invocation, actor: user)
      assert length(invocations) >= 1

      genesis = Enum.find(invocations, fn inv -> inv.sequence_number == 0 end)
      assert genesis
      assert genesis.input == "Hello world"
      assert genesis.network_id == network.id
      assert genesis.state in [:ready, :invoking, :completed]
    end
  end
end
