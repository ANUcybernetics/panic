defmodule PanicWeb.NetworkLiveTest do
  @moduledoc """
  Comprehensive tests for NetworkLive functionality.

  This test suite covers:
  - Basic network management (creation, viewing)
  - The page an expired anonymous terminal lands on
  - Pending restart behavior and immediate genesis creation

  The anonymous terminal itself is tested in `PanicWeb.TerminalLiveTest`.
  """
  use PanicWeb.ConnCase, async: false
  use ExUnitProperties

  import Phoenix.LiveViewTest

  alias Panic.Engine
  alias Panic.Fixtures
  alias Phoenix.Socket.Broadcast

  setup do
    # Setup external API patches to avoid real network calls
    Panic.ExternalAPIPatches.setup()

    :ok
  end

  describe "basic network management - authenticated user" do
    setup {PanicWeb.Helpers, :create_and_sign_in_user}

    test "can create a network which is then listed on the networks page", %{conn: conn} do
      conn
      |> visit("/networks/new")
      |> fill_in("Name", with: "Test network")
      |> fill_in("Description", with: "A network for testing purposes")
      |> submit()
      |> visit("/networks")
      |> assert_has("#networks", text: "Test network")
    end

    test "can visit the terminal for a runnable network", %{conn: conn, user: user} do
      network = user |> Panic.Generators.network_with_dummy_models() |> pick()

      visit(conn, "/networks/#{network.id}/terminal")
    end

    test "can edit a network", %{conn: conn, user: user} do
      network = user |> Panic.Generators.network_with_dummy_models() |> pick()

      conn
      |> visit("/networks/#{network.id}")
      |> click_link("Edit")
      |> fill_in("Name", with: "Updated network name")
      |> fill_in("Description", with: "Updated description")
      |> submit()
      |> assert_has("h1", text: "Updated network name")
    end
  end

  describe "missing platform keys" do
    setup {PanicWeb.Helpers, :create_and_sign_in_user}

    test "a network whose models need a key that isn't set warns its owner", %{
      conn: conn,
      user: user
    } do
      openai = Enum.find(Panic.Model.all(), &(&1.platform == Panic.Platforms.OpenAI))

      network =
        user |> Fixtures.network() |> Engine.update_models!([openai.id], actor: user)

      conn
      |> visit(~p"/networks/#{network}")
      |> assert_has("#missing-keys", text: "No API key set for OpenAI")
      |> assert_has("#missing-keys", text: "Ask an admin")
    end

    test "a network of dummy models doesn't warn", %{conn: conn, user: user} do
      network = Fixtures.network_with_dummy_models(user)

      conn
      |> visit(~p"/networks/#{network}")
      |> refute_has("#missing-keys")
    end
  end

  describe "expired terminal page" do
    setup {PanicWeb.Helpers, :create_and_sign_in_user}

    setup %{user: user} do
      network = create_network(user)
      {:ok, network: network}
    end

    test "displays expired message", %{conn: conn, network: network} do
      conn
      |> visit(~p"/networks/#{network.id}/terminal/expired")
      |> assert_has("h1", text: "QR Code Expired")
      |> assert_has("p", text: "This one has closed")
      |> assert_has("h2", text: "How to get a new QR code")
    end

    test "shows link to network details when logged in", %{
      conn: conn,
      network: network,
      user: _user
    } do
      conn
      |> visit(~p"/networks/#{network.id}/terminal/expired")
      |> assert_has("a", text: "View network details")
      |> assert_has("a[href='/networks/#{network.id}']")
    end

    test "does not show network details link when not logged in", %{conn: conn, network: network} do
      conn = log_out_user(conn)

      conn
      |> visit(~p"/networks/#{network.id}/terminal/expired")
      |> refute_has("a", text: "View network details")
      |> refute_has("a[href='/networks/#{network.id}']")
    end

    test "shows learn more link", %{conn: conn, network: network} do
      conn
      |> visit(~p"/networks/#{network.id}/terminal/expired")
      |> assert_has("a[href='/about']")
    end
  end

  describe "immediate genesis creation on pending restart" do
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
      first_genesis = Engine.start_run!(network, "first prompt", actor: user)

      # Subscribe to the network's invocation topic to verify broadcast
      PanicWeb.Endpoint.subscribe("invocation:#{network.id}")

      # Start a new run while the first is still processing
      # This should return a new genesis immediately
      second_genesis = Engine.start_run!(network, "second prompt", actor: user)

      # Should be different invocations
      assert first_genesis.id != second_genesis.id
      assert second_genesis.input == "second prompt"

      # Watchers are told about the new genesis straight away
      second_genesis_id = second_genesis.id

      assert_receive %Broadcast{
        topic: "invocation:" <> _,
        event: "start_run",
        payload: %{data: %{id: ^second_genesis_id, input: "second prompt"}}
      }
    end

    test "shows immediate feedback in LiveView when new run starts", %{
      conn: conn,
      user: user,
      network: network
    } do
      # Start an initial run
      _genesis = Engine.start_run!(network, "first prompt", actor: user)

      # Open the live view
      {:ok, view, _html} = live(conn, ~p"/networks/#{network}")

      # Start a new run - should create genesis immediately
      _second_genesis = Engine.start_run!(network, "second prompt", actor: user)

      # The view should immediately show the new prompt
      assert render(view) =~ "second prompt"
    end

    test "terminal component handles immediate genesis creation", %{
      conn: conn,
      user: user,
      network: network
    } do
      # Start an initial run
      _genesis = Engine.start_run!(network, "first prompt", actor: user)

      # Submit a new prompt through the terminal while another run is active
      conn
      |> visit(~p"/networks/#{network}")
      |> fill_in("Prompt", with: "new prompt from terminal")
      |> submit()
      |> refute_has("p[role=alert]")
    end
  end

  defp create_network(user) do
    # Use the fixture helper that properly creates networks
    Fixtures.network_with_dummy_models(user)
  end

  defp log_out_user(_conn) do
    Phoenix.ConnTest.build_conn()
  end

  # Helper functions
end
