defmodule PanicWeb.TerminalAuthTest do
  use PanicWeb.ConnCase, async: false

  alias PanicWeb.TerminalAuth

  describe "generate_token/1" do
    test "generates a token for a network ID" do
      token = TerminalAuth.generate_token("123")
      assert is_binary(token)
      assert String.length(token) > 0
    end

    test "generates different tokens for different network IDs" do
      token1 = TerminalAuth.generate_token("123")
      token2 = TerminalAuth.generate_token("456")
      assert token1 != token2
    end

    test "generates different tokens for same network ID at different times" do
      token1 = TerminalAuth.generate_token("123")
      # Small delay to ensure different timestamps
      Process.sleep(10)
      token2 = TerminalAuth.generate_token("123")
      assert token1 != token2
    end
  end

  describe "verify_token/1" do
    test "verifies a valid token" do
      network_id = "123"
      token = TerminalAuth.generate_token(network_id)
      assert {:ok, ^network_id} = TerminalAuth.verify_token(token)
    end

    test "returns error for invalid token" do
      assert {:error, :invalid} = TerminalAuth.verify_token("invalid_token")
    end

    test "returns error for expired token" do
      # This is a bit tricky to test without mocking time
      # We'll test that the function handles expired tokens correctly
      # by using Phoenix.Token directly with a very short max_age
      expired_token =
        Phoenix.Token.sign(PanicWeb.Endpoint, "terminal_access", %{
          network_id: "123",
          # 2 hours ago
          generated_at: System.system_time(:second) - 7200
        })

      assert {:error, :expired} = TerminalAuth.verify_token(expired_token)
    end

    test "returns correct network_id from token" do
      network_id = "test-network-456"
      token = TerminalAuth.generate_token(network_id)
      assert {:ok, ^network_id} = TerminalAuth.verify_token(token)
    end
  end

  describe "generate_terminal_url/1" do
    test "generates a full URL with token" do
      url = TerminalAuth.generate_terminal_url("123")
      assert url =~ ~r{/networks/123/terminal\?token=}
      assert url =~ ~r{^https?://}
    end

    test "includes valid token in URL" do
      network_id = "789"
      url = TerminalAuth.generate_terminal_url(network_id)

      # Extract token from URL
      [_, token] = Regex.run(~r/token=(.+)$/, url)

      assert {:ok, ^network_id} = TerminalAuth.verify_token(token)
    end
  end

  describe "validate_token_in_socket/2" do
    setup do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{},
        endpoint: PanicWeb.Endpoint,
        router: PanicWeb.Router
      }

      {:ok, socket: socket}
    end

    test "validates correct token for network", %{socket: socket} do
      network_id = "123"
      token = TerminalAuth.generate_token(network_id)
      params = %{"network_id" => network_id, "token" => token}

      assert {:ok, _socket} = TerminalAuth.validate_token_in_socket(params, socket)
    end

    test "rejects token for different network", %{socket: socket} do
      token = TerminalAuth.generate_token("123")
      params = %{"network_id" => "456", "token" => token}

      assert {:error, socket} = TerminalAuth.validate_token_in_socket(params, socket)
      assert socket.redirected == {:live, :redirect, %{kind: :push, to: "/networks/456/terminal/expired"}}
    end

    test "rejects expired token", %{socket: socket} do
      network_id = "123"
      # Create an expired token
      expired_token =
        Phoenix.Token.sign(PanicWeb.Endpoint, "terminal_access", %{
          network_id: network_id,
          # 2 hours ago
          generated_at: System.system_time(:second) - 7200
        })

      params = %{"network_id" => network_id, "token" => expired_token}

      assert {:error, socket} = TerminalAuth.validate_token_in_socket(params, socket)
      assert socket.redirected == {:live, :redirect, %{kind: :push, to: "/networks/123/terminal/expired"}}
    end

    test "rejects invalid token", %{socket: socket} do
      params = %{"network_id" => "123", "token" => "invalid"}

      assert {:error, socket} = TerminalAuth.validate_token_in_socket(params, socket)
      assert socket.redirected == {:live, :redirect, %{kind: :push, to: "/networks/123/terminal/expired"}}
    end

    test "rejects missing token", %{socket: socket} do
      params = %{"network_id" => "123"}

      assert {:error, socket} = TerminalAuth.validate_token_in_socket(params, socket)
      assert socket.redirected == {:live, :redirect, %{kind: :push, to: "/networks/123/terminal/expired"}}
    end

    test "redirects to 404 for missing network_id", %{socket: socket} do
      params = %{"token" => "some_token"}

      assert {:error, socket} = TerminalAuth.validate_token_in_socket(params, socket)
      assert socket.redirected == {:live, :redirect, %{kind: :push, to: "/404"}}
    end
  end

  describe "expires_soon?/1" do
    test "returns false for recently generated token" do
      token = TerminalAuth.generate_token("123")
      refute TerminalAuth.expires_soon?(token)
    end

    test "returns true for invalid token" do
      assert TerminalAuth.expires_soon?("invalid_token")
    end

    test "returns true for token close to expiry" do
      # Create a token that's 55 minutes old (expires in 5 minutes)
      old_token =
        Phoenix.Token.sign(PanicWeb.Endpoint, "terminal_access", %{
          network_id: "123",
          # 55 minutes ago
          generated_at: System.system_time(:second) - 3300
        })

      assert TerminalAuth.expires_soon?(old_token)
    end

    test "returns false for token with more than 10 minutes remaining" do
      # Create a token that's 45 minutes old (expires in 15 minutes)
      token =
        Phoenix.Token.sign(PanicWeb.Endpoint, "terminal_access", %{
          network_id: "123",
          # 45 minutes ago
          generated_at: System.system_time(:second) - 2700
        })

      refute TerminalAuth.expires_soon?(token)
    end
  end
end
