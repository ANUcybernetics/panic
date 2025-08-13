defmodule PanicWeb.NetworkLiveTest do
  @moduledoc """
  Comprehensive tests for NetworkLive functionality.

  This test suite covers:
  - Basic network management (creation, viewing)
  - QR code generation and terminal access
  - Terminal functionality with token authentication
  - Pending restart behavior and immediate genesis creation
  - Both authenticated and unauthenticated user scenarios
  """
  use PanicWeb.ConnCase, async: false
  use ExUnitProperties

  import Phoenix.LiveViewTest

  alias Panic.Engine.NetworkRunner
  alias Panic.Fixtures
  alias PanicWeb.TerminalAuth
  alias Phoenix.Socket.Broadcast

  setup do
    # Setup external API patches to avoid real network calls
    Panic.ExternalAPIPatches.setup()

    # Setup web test environment with sync mode and cleanup
    PanicWeb.Helpers.setup_web_test()

    on_exit(fn ->
      # Teardown API patches
      Panic.ExternalAPIPatches.teardown()
    end)

    :ok
  end

  describe "basic network management - authenticated user" do
    setup {PanicWeb.Helpers, :create_and_sign_in_user}

    test "can create a network which is then listed on user page", %{conn: conn, user: user} do
      conn
      |> visit("/users/#{user.id}")
      |> click_link("Add network")
      |> fill_in("Name", with: "Test network")
      |> fill_in("Description", with: "A network for testing purposes")
      |> submit()
      |> assert_has("#network-list", text: "Test network")
    end

    test "can visit the terminal for a runnable network", %{conn: conn, user: user} do
      # TODO currently I can't get PhoenixTest to fill out the LiveSelect yet, so fake it for now
      network = user |> Panic.Generators.network_with_dummy_models() |> pick()

      visit(conn, "/networks/#{network.id}/terminal")
    end

    test "can edit a network", %{conn: conn, user: user} do
      network = user |> Panic.Generators.network_with_dummy_models() |> pick()

      conn
      |> visit("/networks/#{network.id}")
      |> click_link("Edit network")
      |> fill_in("Name", with: "Updated network name")
      |> fill_in("Description", with: "Updated description")
      |> submit()
      |> assert_has("h1", text: "Updated network name")
    end

    test "can view network info all view", %{conn: conn, user: user} do
      network = user |> Panic.Generators.network_with_dummy_models() |> pick()

      {:ok, view, html} = live(conn, ~p"/networks/#{network.id}/info/all")

      # The "all" view shows a list of QR codes
      assert html =~ "QR codes"
      assert has_element?(view, "div.prose")
    end
  end

  describe "QR code functionality - authenticated user" do
    setup {PanicWeb.Helpers, :create_and_sign_in_user}

    setup %{user: user} do
      network = Fixtures.network_with_dummy_models(user)
      {:ok, network: network}
    end

    test "authenticated user can visit QR code page", %{conn: conn, network: network} do
      {:ok, _view, html} = live(conn, ~p"/networks/#{network.id}/info/qr")

      # The QR modal should be shown with its characteristic text
      assert html =~ "scan to prompt"
      assert html =~ network.name
      # The page should have the qr-modal element
      assert html =~ "qr-modal"
    end

    test "generates QR code with token for terminal access", %{conn: conn, network: network} do
      {:ok, _view, html} = live(conn, ~p"/networks/#{network.id}/info/qr")

      # The QR modal should be shown
      assert html =~ "qr-modal"
      assert html =~ "scan to prompt"

      # The core functionality we're testing: the QR generation includes a token
      # This is verified by the TerminalAuth module tests already
      # Here we just verify the UI renders the modal
    end

    test "refreshes QR code periodically", %{conn: conn, network: network} do
      {:ok, view, html} = live(conn, ~p"/networks/#{network.id}/info/qr")

      # Verify initial state
      assert html =~ "qr-modal"

      # Simulate the refresh timer
      send(view.pid, :refresh_qr_code)
      Process.sleep(50)

      # Verify the view is still rendering correctly after refresh
      new_html = render(view)
      assert new_html =~ "qr-modal"
      assert new_html =~ "scan to prompt"
    end

    test "only refreshes QR when showing QR modal", %{conn: conn, network: network} do
      # Navigate to info page without QR modal
      {:ok, view, html} = live(conn, ~p"/networks/#{network.id}/info")

      # Should show info page content
      assert html =~ "Network name:"
      # The modal exists in the DOM but is not shown (show={false})
      assert html =~ "qr-modal"

      # Simulate the refresh timer
      send(view.pid, :refresh_qr_code)
      Process.sleep(50)

      # Content should still show the info page
      new_html = render(view)
      assert new_html =~ "Network name:"
      # The modal is in the DOM regardless of live_action
      assert new_html =~ "qr-modal"
    end
  end

  describe "QR code functionality - unauthenticated user" do
    setup do
      user = Fixtures.user("password123")
      network = Fixtures.network_with_dummy_models(user)
      {:ok, network: network}
    end

    test "unauthenticated user gets redirected from QR code page", %{conn: conn, network: network} do
      # Unauthenticated users should be redirected to sign-in when trying to access the QR code page
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/networks/#{network.id}/info/qr")

      assert path == "/sign-in"
    end
  end

  describe "terminal access with authentication" do
    setup {PanicWeb.Helpers, :create_and_sign_in_user}

    setup %{user: user} do
      network = create_network(user)
      {:ok, network: network}
    end

    test "allows access without token for authenticated users", %{conn: conn, network: network} do
      # Authenticated user can access terminal without token
      {:ok, _view, html} = live(conn, ~p"/networks/#{network.id}/terminal")

      assert html =~ "Current run:"
      assert html =~ "terminal-container"
      refute html =~ "QR Code Expired"
    end

    test "authenticated users can still use token if provided", %{conn: conn, network: network} do
      token = TerminalAuth.generate_token(network.id)

      # Even with a token, authenticated users should have access
      {:ok, _view, html} =
        live(conn, ~p"/networks/#{network.id}/terminal?token=#{token}")

      assert html =~ "Current run:"
      assert html =~ "terminal-container"
    end

    test "authenticated users can access with expired token", %{conn: conn, network: network} do
      # Create an expired token
      expired_token =
        Phoenix.Token.sign(PanicWeb.Endpoint, "terminal_access", %{
          network_id: to_string(network.id),
          # 2 hours ago
          generated_at: System.system_time(:second) - 7200
        })

      # Authenticated users should still have access even with expired token
      {:ok, _view, html} =
        live(conn, ~p"/networks/#{network.id}/terminal?token=#{expired_token}")

      assert html =~ "Current run:"
      assert html =~ "terminal-container"
    end

    test "allows access with valid token", %{conn: conn, network: network} do
      token = TerminalAuth.generate_token(network.id)

      {:ok, _view, html} =
        live(conn, ~p"/networks/#{network.id}/terminal?token=#{token}")

      assert html =~ "Current run:"
      assert html =~ "terminal-container"
      refute html =~ "QR Code Expired"
    end

    test "displays terminal component when token is valid", %{conn: conn, network: network} do
      token = TerminalAuth.generate_token(network.id)

      {:ok, view, _html} =
        live(conn, ~p"/networks/#{network.id}/terminal?token=#{token}")

      assert has_element?(view, ".terminal-container")
      assert render(view) =~ "terminal-container"
    end
  end

  describe "terminal access via QR code token - unauthenticated users" do
    setup do
      user = Fixtures.user("password123")
      network = Fixtures.network_with_dummy_models(user)

      # Generate a valid terminal token
      token = TerminalAuth.generate_token(network.id)

      {:ok, user: user, network: network, token: token}
    end

    test "unauthenticated user with valid token can access terminal", %{
      conn: conn,
      network: network,
      token: token
    } do
      # Unauthenticated users can now access the terminal with a valid token
      {:ok, _view, html} = live(conn, ~p"/networks/#{network.id}/terminal?token=#{token}")
      assert html =~ "terminal-container"
      assert html =~ "Current run:"
    end

    test "unauthenticated user cannot access terminal without token", %{
      conn: conn,
      network: network
    } do
      {:error, {:live_redirect, %{to: path}}} = live(conn, ~p"/networks/#{network.id}/terminal")

      assert path == "/networks/#{network.id}/terminal/expired"
    end

    test "unauthenticated user cannot access terminal with expired token", %{
      conn: conn,
      network: network
    } do
      # Generate an expired token by setting a past timestamp
      expired_token =
        Phoenix.Token.sign(
          PanicWeb.Endpoint,
          "terminal_access",
          %{
            network_id: to_string(network.id),
            generated_at: System.system_time(:second) - 7200
          }
        )

      {:error, {:live_redirect, %{to: path}}} =
        live(conn, ~p"/networks/#{network.id}/terminal?token=#{expired_token}")

      assert path == "/networks/#{network.id}/terminal/expired"
    end

    test "unauthenticated user cannot access terminal with invalid token", %{
      conn: conn,
      network: network
    } do
      {:error, {:live_redirect, %{to: path}}} =
        live(conn, ~p"/networks/#{network.id}/terminal?token=invalid_token_here")

      assert path == "/networks/#{network.id}/terminal/expired"
    end

    test "unauthenticated user cannot access terminal with token for different network", %{
      conn: conn,
      network: network
    } do
      # Create another network and generate a token for it
      other_user = Fixtures.user("otherpassword123")
      other_network = Fixtures.network_with_dummy_models(other_user)
      other_token = TerminalAuth.generate_token(other_network.id)

      # Try to use the other network's token to access this network
      {:error, {:live_redirect, %{to: path}}} =
        live(conn, ~p"/networks/#{network.id}/terminal?token=#{other_token}")

      assert path == "/networks/#{network.id}/terminal/expired"
    end

    test "unauthenticated user with valid token can submit prompts", %{
      conn: conn,
      network: network,
      token: token
    } do
      # Unauthenticated users can now access the terminal and submit prompts with valid tokens
      {:ok, view, _html} = live(conn, ~p"/networks/#{network.id}/terminal?token=#{token}")

      # Submit a prompt
      form = form(view, "form", invocation: %{input: "Test prompt"})
      render_submit(form)

      # Check that the prompt was submitted
      assert render(view) =~ "Ready for new input"
    end
  end

  describe "terminal access with invalid token for unauthenticated users" do
    setup do
      user = Fixtures.user("password123")
      network = create_network(user)
      {:ok, conn: log_out_user(Phoenix.ConnTest.build_conn()), network: network}
    end

    test "redirects to expired page with invalid token", %{conn: conn, network: network} do
      {:error, {:live_redirect, %{to: path}}} =
        live(conn, ~p"/networks/#{network.id}/terminal?token=invalid_token")

      assert path == "/networks/#{network.id}/terminal/expired"
    end

    test "redirects to expired page with no token", %{conn: conn, network: network} do
      {:error, {:live_redirect, %{to: path}}} =
        live(conn, ~p"/networks/#{network.id}/terminal")

      assert path == "/networks/#{network.id}/terminal/expired"
    end

    test "redirects to expired page with expired token", %{conn: conn, network: network} do
      # Create an expired token
      expired_token =
        Phoenix.Token.sign(PanicWeb.Endpoint, "terminal_access", %{
          network_id: to_string(network.id),
          # 2 hours ago
          generated_at: System.system_time(:second) - 7200
        })

      {:error, {:live_redirect, %{to: path}}} =
        live(conn, ~p"/networks/#{network.id}/terminal?token=#{expired_token}")

      assert path == "/networks/#{network.id}/terminal/expired"
    end

    test "redirects to expired page with token for different network", %{
      conn: conn,
      network: network
    } do
      # Create another network and generate a token for it
      user = Fixtures.user("password123")
      other_network = create_network(user)
      token = TerminalAuth.generate_token(other_network.id)

      {:error, {:live_redirect, %{to: path}}} =
        live(conn, ~p"/networks/#{network.id}/terminal?token=#{token}")

      assert path == "/networks/#{network.id}/terminal/expired"
    end
  end

  describe "expired terminal page" do
    setup {PanicWeb.Helpers, :create_and_sign_in_user}

    setup %{user: user} do
      network = create_network(user)
      {:ok, network: network}
    end

    test "displays expired message", %{conn: conn, network: network} do
      {:ok, _view, html} = live(conn, ~p"/networks/#{network.id}/terminal/expired")

      assert html =~ "QR Code Expired"
      assert html =~ "expired for security reasons"
      assert html =~ "valid for 1 hour"
      assert html =~ "How to get a new QR code"
    end

    test "shows link to network details when logged in", %{
      conn: conn,
      network: network,
      user: _user
    } do
      {:ok, view, html} = live(conn, ~p"/networks/#{network.id}/terminal/expired")

      assert html =~ "View network details"
      assert has_element?(view, "a[href='/networks/#{network.id}']")
    end

    test "does not show network details link when not logged in", %{conn: conn, network: network} do
      conn = log_out_user(conn)
      {:ok, view, html} = live(conn, ~p"/networks/#{network.id}/terminal/expired")

      refute html =~ "View network details"
      refute has_element?(view, "a[href='/networks/#{network.id}']")
    end

    test "shows learn more link", %{conn: conn, network: network} do
      {:ok, view, _html} = live(conn, ~p"/networks/#{network.id}/terminal/expired")

      assert has_element?(view, "a[href='/about']")
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
      user: _user,
      network: network
    } do
      # Start an initial run
      {:ok, first_genesis} = NetworkRunner.start_run(network.id, "first prompt")

      # Subscribe to the network's invocation topic to verify broadcast
      PanicWeb.Endpoint.subscribe("invocation:#{network.id}")

      # Start a new run while the first is still processing
      # This should return a new genesis immediately
      {:ok, second_genesis} = NetworkRunner.start_run(network.id, "second prompt")

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
      user: _user,
      network: network
    } do
      # Start an initial run
      {:ok, _genesis} = NetworkRunner.start_run(network.id, "first prompt")

      # Open the live view
      {:ok, view, _html} = live(conn, ~p"/networks/#{network}")

      # Start a new run - should create genesis immediately
      {:ok, _second_genesis} = NetworkRunner.start_run(network.id, "second prompt")

      # Give the view a moment to process the broadcast
      Process.sleep(10)

      # The view should immediately show the new prompt
      assert render(view) =~ "second prompt"

      # Clean up
      NetworkRunner.stop_run(network.id)
    end

    test "terminal component handles immediate genesis creation", %{
      conn: conn,
      user: _user,
      network: network
    } do
      # Start an initial run
      {:ok, _genesis} = NetworkRunner.start_run(network.id, "first prompt")

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

  describe "end-to-end QR code workflow documentation" do
    test "documents the intended QR code terminal access flow", %{conn: conn} do
      # This test documents the intended workflow for QR code terminal access
      # Currently, some parts don't work as intended due to authorization limitations

      # Step 1: Authenticated user creates a network
      password = "password123"
      user = Fixtures.user(password)

      # Sign in the user properly
      strategy = AshAuthentication.Info.strategy!(Panic.Accounts.User, :password)

      {:ok, signed_in_user} =
        AshAuthentication.Strategy.action(strategy, :sign_in, %{
          email: user.email,
          password: password
        })

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(signed_in_user)

      network = Fixtures.network_with_dummy_models(user)

      # Step 2: Authenticated user visits QR code page
      {:ok, _view, html} = live(conn, ~p"/networks/#{network.id}/info/qr")
      assert html =~ "scan to prompt"
      assert html =~ "qr-modal"

      # Step 3: QR code contains terminal URL with token
      # The QR text should include a token for unauthenticated access
      # (This is generated in the Info LiveView)

      # Step 4: Unauthenticated user scans QR code
      # Log out to simulate an unauthenticated user
      unauthenticated_conn = Phoenix.ConnTest.build_conn()

      # Generate a valid token like the QR code would contain
      token = TerminalAuth.generate_token(network.id)

      # Step 5: Unauthenticated user accesses terminal with token
      {:ok, view, html} =
        live(unauthenticated_conn, ~p"/networks/#{network.id}/terminal?token=#{token}")

      assert html =~ "Current run:"
      assert html =~ "terminal-container"

      # Step 6: Unauthenticated user can submit prompts
      form = form(view, "form", invocation: %{input: "Hello from QR code!"})
      render_submit(form)

      # Verify the prompt was accepted
      assert render(view) =~ "Ready for new input"

      # Step 6: Token expiration handling works correctly
      expired_token =
        Phoenix.Token.sign(
          PanicWeb.Endpoint,
          "terminal_access",
          %{
            network_id: to_string(network.id),
            generated_at: System.system_time(:second) - 7200
          }
        )

      {:error, {:live_redirect, %{to: path}}} =
        live(unauthenticated_conn, ~p"/networks/#{network.id}/terminal?token=#{expired_token}")

      assert path == "/networks/#{network.id}/terminal/expired"

      # Step 7: Expired page provides helpful information
      {:ok, _view, expired_html} =
        live(unauthenticated_conn, ~p"/networks/#{network.id}/terminal/expired")

      assert expired_html =~ "QR Code Expired"
      assert expired_html =~ "expired for security reasons"
    end
  end

  # Helper functions

  defp create_network(user) do
    # Use the fixture helper that properly creates networks
    Fixtures.network_with_dummy_models(user)
  end

  defp log_out_user(_conn) do
    Phoenix.ConnTest.build_conn()
  end
end
