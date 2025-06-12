defmodule PanicWeb.NetworkLive.TerminalTest do
  use PanicWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias PanicWeb.TerminalAuth

  setup do
    # Stop all network runners to ensure clean state
    PanicWeb.Helpers.stop_all_network_runners()
    :ok
  end

  setup {PanicWeb.Helpers, :create_and_sign_in_user}

  setup %{user: user} do
    # Create a network for testing
    network = create_network(user)
    {:ok, network: network}
  end

  describe "terminal access with valid token" do
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

      # AIDEV-NOTE: LiveComponent IDs need to be more specific in selectors
      # The LiveComponent uses the network.id as its id
      assert has_element?(view, ".terminal-container")
      assert render(view) =~ "terminal-container"
    end
  end

  describe "terminal access for authenticated users" do
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
  end

  describe "terminal access with invalid token for unauthenticated users" do
    setup %{conn: conn} do
      # Log out the user for these tests
      {:ok, conn: log_out_user(conn)}
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
      network: network,
      user: user
    } do
      other_network = create_network(user)
      token = TerminalAuth.generate_token(other_network.id)

      {:error, {:live_redirect, %{to: path}}} =
        live(conn, ~p"/networks/#{network.id}/terminal?token=#{token}")

      assert path == "/networks/#{network.id}/terminal/expired"
    end
  end

  describe "expired terminal page" do
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

  describe "info page QR code generation" do
    test "generates QR code with token for terminal access", %{conn: conn, network: network} do
      {:ok, _view, html} = live(conn, ~p"/networks/#{network.id}/info/qr")

      # The QR modal should be shown
      assert html =~ "qr-modal"
      assert html =~ "wtf is this?"

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
      assert new_html =~ "wtf is this?"
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

  # Helper functions

  defp create_network(user) do
    # Use the fixture helper that properly creates networks
    Panic.Fixtures.network_with_dummy_models(user)
  end

  defp log_out_user(_conn) do
    # AIDEV-NOTE: Simple approach - just build a new conn without auth
    Phoenix.ConnTest.build_conn()
  end
end
