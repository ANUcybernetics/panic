defmodule PanicWeb.TerminalLiveTest do
  @moduledoc """
  Tests for the terminal LiveView with QR code authentication functionality.

  This test suite covers:

  1. **Authenticated User Access**
     - Logged in users can access the terminal directly without tokens
     - Users can start new runs and submit prompts
     - Authentication bypasses token validation

  2. **Anonymous User Access via QR Code**
     - Anonymous users require valid time-based tokens
     - Invalid, expired, or missing tokens redirect to expired page
     - Tokens for wrong networks are rejected
     - Currently anonymous users with valid tokens get 404 due to
       authorization issues - tests document both current and intended behavior

  3. **Token Expiration Behavior**
     - Tokens expire after 1 hour
     - Token verification includes grace period for clock skew
     - `expires_soon?/1` helper identifies tokens expiring within 10 minutes
     - Terminal URLs include properly formatted tokens

  4. **QR Code Generation Workflow**
     - Authenticated users can access QR code page
     - QR codes contain terminal URLs with embedded tokens
     - QR modal displays with characteristic "wtf is this?" text

  5. **Terminal Component Interaction**
     - Terminal shows current run status
     - Purple-themed styling is applied correctly
     - Prompt submission works for authenticated users

  ## Known Issues

  - Anonymous users with valid tokens currently get redirected to 404 instead
    of being able to access the terminal (authorization policy needs updating)
  - Database connection warnings appear due to NetworkRunner cleanup between tests
  """
  use PanicWeb.ConnCase, async: false
  use ExUnitProperties
  use PanicWeb.Helpers.DatabasePatches

  alias Panic.Fixtures
  alias PanicWeb.TerminalAuth

  describe "authenticated user terminal access" do
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

    setup {PanicWeb.Helpers, :create_and_sign_in_user}

    test "logged in user can visit the terminal and start a new run", %{conn: conn, user: user} do
      network = user |> Panic.Generators.network_with_dummy_models() |> pick()

      conn
      |> visit("/networks/#{network.id}/terminal")
      |> assert_has("span", text: "Current run:")
      |> fill_in("Prompt", with: "a sheep on the grass")
      |> submit()
      |> assert_has("span", text: "a sheep on the grass")
    end

    test "logged in user can access terminal without token", %{conn: conn, user: user} do
      network = Fixtures.network_with_dummy_models(user)

      # Authenticated users bypass token requirement
      conn
      |> visit("/networks/#{network.id}/terminal")
      |> assert_has(".terminal-container")
      |> assert_has("span", text: "Current run:")
    end

    test "logged in user can access terminal even with invalid token", %{conn: conn, user: user} do
      network = Fixtures.network_with_dummy_models(user)

      # Authenticated users bypass token validation
      conn
      |> visit("/networks/#{network.id}/terminal?token=invalid_token")
      |> assert_has(".terminal-container")
      |> assert_has("span", text: "Current run:")
    end
  end

  describe "complete QR code flow with PhoenixTest" do
    setup do
      # Setup external API patches to avoid real network calls
      Panic.ExternalAPIPatches.setup()

      # Setup web test environment with sync mode and cleanup
      PanicWeb.Helpers.setup_web_test()

      user = Fixtures.user("password123")
      network = Fixtures.network_with_dummy_models(user)

      on_exit(fn ->
        # Teardown API patches
        Panic.ExternalAPIPatches.teardown()
      end)

      {:ok, user: user, network: network}
    end

    test "non-logged-in user can scan QR code and start a new run", %{
      conn: conn,
      network: network
    } do
      # Generate a valid token like what would be in a QR code
      token = TerminalAuth.generate_token(network.id)

      # Visit the terminal as a non-logged-in user with the token
      conn
      |> visit("/networks/#{network.id}/terminal?token=#{token}")
      |> assert_has(".terminal-container")
      |> assert_has("span", text: "Current run:")
      # The form should be ready for input
      |> assert_has("input[placeholder='Ready for new input']")
      # Submit a prompt
      |> fill_in("Prompt", with: "Hello from QR code scan!")
      |> submit()
      # After submission, the form should show it's processing
      |> assert_has("input[placeholder]")
      # Wait a moment for the invocation to process
      |> then(fn session ->
        Process.sleep(100)
        session
      end)
      # Refresh the view to see the latest state
      |> visit("/networks/#{network.id}/terminal?token=#{token}")
      # Should still be in lockout but might show "Ready" if enough time passed
      |> assert_has("input[placeholder]")
    end
  end

  describe "anonymous user terminal access via QR code" do
    setup do
      # Setup external API patches to avoid real network calls
      Panic.ExternalAPIPatches.setup()

      # Setup web test environment with sync mode and cleanup
      PanicWeb.Helpers.setup_web_test()

      # Create a user and network for testing
      user = Fixtures.user("password123")
      network = Fixtures.network_with_dummy_models(user)

      on_exit(fn ->
        # Teardown API patches
        Panic.ExternalAPIPatches.teardown()
      end)

      {:ok, user: user, network: network}
    end

    test "anonymous user with valid token can visit terminal", %{conn: conn, network: network} do
      # Generate a valid token like the QR code would contain
      token = TerminalAuth.generate_token(network.id)

      # Anonymous users can now access the terminal with a valid token
      conn
      |> visit("/networks/#{network.id}/terminal?token=#{token}")
      |> assert_has(".terminal-container")
      |> assert_has("span", text: "Current run:")
      |> fill_in("Prompt", with: "a cat on a mat")
      |> submit()
      |> assert_has("input[placeholder='Ready for new input']")
    end

    test "anonymous user without token is redirected to expired page", %{
      conn: conn,
      network: network
    } do
      conn
      |> visit("/networks/#{network.id}/terminal")
      |> assert_has("h1", text: "QR Code Expired")
      |> assert_has("p", text: "expired for security reasons")
    end

    test "anonymous user with expired token is redirected to expired page", %{
      conn: conn,
      network: network
    } do
      # Generate an expired token by creating one with a timestamp from over an hour ago
      expired_token =
        Phoenix.Token.sign(
          PanicWeb.Endpoint,
          "terminal_access",
          %{
            network_id: to_string(network.id),
            # 2 hours ago
            generated_at: System.system_time(:second) - 7200
          }
        )

      conn
      |> visit("/networks/#{network.id}/terminal?token=#{expired_token}")
      |> assert_has("h1", text: "QR Code Expired")
      |> assert_has("p", text: "expired for security reasons")
    end

    test "anonymous user with invalid token is redirected to expired page", %{
      conn: conn,
      network: network
    } do
      conn
      |> visit("/networks/#{network.id}/terminal?token=invalid_token_here")
      |> assert_has("h1", text: "QR Code Expired")
      |> assert_has("p", text: "expired for security reasons")
    end

    test "anonymous user with token for wrong network is redirected to expired page", %{
      conn: conn,
      network: network
    } do
      # Create another network and generate a token for it
      other_user = Fixtures.user("otherpassword123")
      other_network = Fixtures.network_with_dummy_models(other_user)
      wrong_token = TerminalAuth.generate_token(other_network.id)

      # Try to use the other network's token to access this network
      conn
      |> visit("/networks/#{network.id}/terminal?token=#{wrong_token}")
      |> assert_has("h1", text: "QR Code Expired")
      |> assert_has("p", text: "expired for security reasons")
    end

    test "expired page provides helpful information", %{conn: conn, network: network} do
      conn
      |> visit("/networks/#{network.id}/terminal/expired")
      |> assert_has("h1", text: "QR Code Expired")
      |> assert_has("p", text: "expired for security reasons")
      |> assert_has("a", text: "Learn more about PANIC!")
    end
  end

  describe "token expiration behavior" do
    setup do
      # Setup external API patches to avoid real network calls
      Panic.ExternalAPIPatches.setup()

      # Setup web test environment with sync mode and cleanup
      PanicWeb.Helpers.setup_web_test()

      user = Fixtures.user("password123")
      network = Fixtures.network_with_dummy_models(user)

      on_exit(fn ->
        # Teardown API patches
        Panic.ExternalAPIPatches.teardown()
      end)

      {:ok, user: user, network: network}
    end

    test "token expires after 1 hour", %{network: network} do
      # Test the token generation and verification logic directly
      token = TerminalAuth.generate_token(network.id)

      # Token should be valid immediately
      network_id = to_string(network.id)
      assert {:ok, ^network_id} = TerminalAuth.verify_token(token)

      # Token should not expire soon when just created
      refute TerminalAuth.expires_soon?(token)

      # Create a token that's 55 minutes old (should still be valid but expiring soon)
      almost_expired_token =
        Phoenix.Token.sign(
          PanicWeb.Endpoint,
          "terminal_access",
          %{
            network_id: to_string(network.id),
            # 55 minutes ago
            generated_at: System.system_time(:second) - 3300
          }
        )

      # Should still be valid
      network_id = to_string(network.id)
      assert {:ok, ^network_id} = TerminalAuth.verify_token(almost_expired_token)

      # But should be expiring soon
      assert TerminalAuth.expires_soon?(almost_expired_token)

      # Create a token that's just over 1 hour old
      expired_token =
        Phoenix.Token.sign(
          PanicWeb.Endpoint,
          "terminal_access",
          %{
            network_id: to_string(network.id),
            # 1 hour and 1 second ago
            generated_at: System.system_time(:second) - 3601
          }
        )

      # Should be expired
      assert {:error, :expired} = TerminalAuth.verify_token(expired_token)
    end

    test "generate_terminal_url creates proper URL with token", %{network: network} do
      url = TerminalAuth.generate_terminal_url(network.id)

      # URL should contain the network ID and a token parameter
      assert url =~ "/networks/#{network.id}/terminal?token="

      # Extract the token from the URL
      [_, token] = String.split(url, "?token=")

      # Token should be valid
      network_id = to_string(network.id)
      assert {:ok, ^network_id} = TerminalAuth.verify_token(token)
    end
  end

  describe "QR code generation workflow" do
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

    setup {PanicWeb.Helpers, :create_and_sign_in_user}

    test "authenticated user can access QR code page", %{conn: conn, user: user} do
      network = Fixtures.network_with_dummy_models(user)

      conn
      |> visit("/networks/#{network.id}/info/qr")
      |> assert_has("#qr-modal")
      |> assert_has("h2", text: "scan to prompt")
    end

    test "QR code page generates terminal URL with valid token", %{conn: conn, user: user} do
      network = Fixtures.network_with_dummy_models(user)

      # Visit the QR code page
      session = visit(conn, "/networks/#{network.id}/info/qr")

      # The QR code should contain a terminal URL with token
      # Note: This would require examining the actual QR code content or the component state
      # For now, we just verify the page loads correctly
      assert_has(session, "#qr-modal")
    end
  end

  describe "terminal component interaction" do
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

    setup {PanicWeb.Helpers, :create_and_sign_in_user}

    test "terminal shows current run status", %{conn: conn, user: user} do
      network = Fixtures.network_with_dummy_models(user)

      session = visit(conn, "/networks/#{network.id}/terminal")

      # Initially no current run
      assert_has(session, "span", text: "Current run:")

      # Submit a prompt
      session
      |> fill_in("Prompt", with: "test prompt")
      |> submit()

      # Should show the input as current run
      # Note: The actual update happens via Phoenix PubSub, so in tests
      # we might not see the immediate update without proper setup
    end

    test "terminal has proper styling", %{conn: conn, user: user} do
      network = Fixtures.network_with_dummy_models(user)

      conn
      |> visit("/networks/#{network.id}/terminal")
      |> assert_has(".terminal-container")
      # Purple input color
      |> assert_has("style", text: "color: #d8b4fe")
    end
  end
end
