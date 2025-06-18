defmodule PanicWeb.NetworkLive.PendingRestartTest do
  use PanicWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Panic.Engine.NetworkRunner
  alias Panic.Fixtures
  alias Phoenix.Socket.Broadcast

  setup do
    # Stop all network runners to ensure clean state
    PanicWeb.Helpers.stop_all_network_runners()
    :ok
  end

  describe "immediate genesis creation" do
    setup {PanicWeb.Helpers, :create_and_sign_in_user}

    setup %{user: user} do
      network = Fixtures.network_with_dummy_models(user)
      # Disable lockout for testing
      network =
        network
        |> Ash.Changeset.for_update(:update, %{lockout_seconds: 0}, actor: user)
        |> Ash.update!()

      {:ok, network: network}
    end

    test "creates genesis immediately when starting new run while another is active", %{
      user: user,
      network: network
    } do
      # Start an initial run
      {:ok, first_genesis} = NetworkRunner.start_run(network.id, "first prompt", user)

      # Subscribe to the network's invocation topic to verify broadcast
      PanicWeb.Endpoint.subscribe("invocation:#{network.id}")

      # Start a new run while the first is still processing
      # This should return a new genesis immediately
      {:ok, second_genesis} = NetworkRunner.start_run(network.id, "second prompt", user)

      # Should be different invocations
      assert first_genesis.id != second_genesis.id
      assert second_genesis.input == "second prompt"

      # Verify we received the about_to_invoke broadcast for the new genesis
      second_genesis_id = second_genesis.id

      assert_receive %Broadcast{
        topic: "invocation:" <> _,
        event: "about_to_invoke",
        payload: %{data: %{id: ^second_genesis_id, input: "second prompt"}}
      }

      # Clean up
      NetworkRunner.stop_run(network.id)
    end

    test "shows immediate feedback in LiveView when new run starts", %{
      conn: conn,
      user: user,
      network: network
    } do
      # Start an initial run
      {:ok, _genesis} = NetworkRunner.start_run(network.id, "first prompt", user)

      # Open the live view
      {:ok, view, _html} = live(conn, ~p"/networks/#{network}")

      # Start a new run - should create genesis immediately
      {:ok, _second_genesis} = NetworkRunner.start_run(network.id, "second prompt", user)

      # Give the view a moment to process the broadcast
      Process.sleep(10)

      # The view should immediately show the new prompt
      assert render(view) =~ "second prompt"

      # Clean up
      NetworkRunner.stop_run(network.id)
    end

    test "terminal component handles immediate genesis creation", %{conn: conn, user: user, network: network} do
      # Start an initial run
      {:ok, _genesis} = NetworkRunner.start_run(network.id, "first prompt", user)

      # Open the live view
      {:ok, view, _html} = live(conn, ~p"/networks/#{network}")

      # Submit a new prompt through the terminal while another run is active
      view
      |> form("form[phx-submit=\"start-run\"]", invocation: %{input: "new prompt from terminal"})
      |> render_submit()

      # The form should be reset and ready for another submission
      # (no error should be shown)
      refute render(view) =~ "alert-danger"

      # Clean up
      NetworkRunner.stop_run(network.id)
    end
  end
end
