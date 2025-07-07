defmodule PanicWeb.NetworkLive.TerminalTest do
  use PanicWeb.ConnCase, async: false

  import Panic.Fixtures
  import Phoenix.LiveViewTest

  alias Panic.Engine.Network
  alias PanicWeb.TerminalAuth

  describe "anonymous user with QR code token" do
    setup do
      # Clean up any running NetworkRunners
      PanicWeb.Helpers.stop_all_network_runners()

      # Create a user with API tokens
      user = user()

      # Create a network owned by the user
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

      # Update the network to add a dummy model
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

      # Generate a valid terminal token
      token = TerminalAuth.generate_token(network.id)

      %{network: network, user: user, token: token}
    end

    test "can access terminal with valid token and start run successfully", %{
      conn: conn,
      network: network,
      token: token,
      user: user
    } do
      # Access terminal as anonymous user with token
      {:ok, view, _html} =
        live(conn, "/networks/#{network.id}/terminal?token=#{token}")

      # Verify we can see the terminal interface
      assert has_element?(view, "[phx-submit=\"start-run\"]")

      # Submit a prompt - this should now work
      view
      |> form("[phx-submit=\"start-run\"]", invocation: %{input: "Hello world"})
      |> render_submit()

      # Give the system a moment to process
      Process.sleep(200)

      # Check that invocations were created successfully
      invocations = Ash.read!(Panic.Engine.Invocation, actor: user)
      assert length(invocations) >= 1

      # Check the first invocation (genesis)
      genesis = Enum.find(invocations, fn inv -> inv.sequence_number == 0 end)
      assert genesis != nil
      assert genesis.input == "Hello world"
      assert genesis.network_id == network.id
      assert genesis.state in [:ready, :invoking, :completed]
    end
  end
end
