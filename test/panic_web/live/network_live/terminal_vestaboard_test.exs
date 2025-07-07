defmodule PanicWeb.NetworkLive.TerminalVestaboardTest do
  use PanicWeb.ConnCase, async: false

  import Panic.Fixtures
  import Phoenix.LiveViewTest

  alias Panic.Engine.Installation
  alias Panic.Engine.Network
  alias PanicWeb.TerminalAuth

  describe "anonymous user with vestaboard watchers" do
    setup do
      # Clean up any running NetworkRunners
      PanicWeb.Helpers.stop_all_network_runners()

      # Enable sync mode for predictable tests
      Panic.NetworkRunnerTestHelpers.enable_sync_mode()

      on_exit(fn ->
        Panic.NetworkRunnerTestHelpers.disable_sync_mode()
      end)

      # Create a user with vestaboard tokens - API calls are mocked
      user = user_with_vestaboard_tokens()

      # Create a network owned by the user
      {:ok, network} =
        Network
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Test Network with Vestaboard",
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

      # Create an installation with a Vestaboard watcher
      {:ok, installation} =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Test Installation",
            network_id: network.id,
            watchers: [
              %{
                type: :vestaboard,
                name: "test-board",
                vestaboard_name: :panic_1,
                stride: 1,
                offset: 0,
                initial_prompt: true
              }
            ]
          },
          actor: user
        )
        |> Ash.create()

      # Generate a valid terminal token
      token = TerminalAuth.generate_token(network.id)

      %{network: network, user: user, token: token, installation: installation}
    end

    test "can start run with vestaboard watcher configured", %{conn: conn, network: network, token: token, user: user} do
      # Access terminal as anonymous user with token
      {:ok, view, _html} =
        live(conn, "/networks/#{network.id}/terminal?token=#{token}")

      # Verify we can see the terminal interface
      assert has_element?(view, "[phx-submit=\"start-run\"]")

      # Submit a prompt - this should trigger vestaboard dispatch
      view
      |> form("[phx-submit=\"start-run\"]", invocation: %{input: "Hello Vestaboard"})
      |> render_submit()

      # Give the system a moment to process
      Process.sleep(200)

      # Check that invocations were created successfully
      invocations = Ash.read!(Panic.Engine.Invocation, actor: user)
      assert length(invocations) >= 1

      # Check the first invocation (genesis)
      genesis = Enum.find(invocations, fn inv -> inv.sequence_number == 0 end)
      assert genesis != nil
      assert genesis.input == "Hello Vestaboard"
      assert genesis.network_id == network.id
      assert genesis.state in [:ready, :invoking, :completed]
    end
  end
end
