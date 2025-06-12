defmodule PanicWeb.TerminalAuth do
  @moduledoc """
  Handles time-based authentication tokens for terminal access.

  This module provides functionality to generate and verify time-limited tokens
  that are embedded in QR codes for terminal access. Tokens are valid for 1 hour
  and are scoped to specific networks.

  ## Authentication Bypass

  Authenticated users (those logged in to the system) can access the terminal
  without a token. This allows network owners and authorized users to access
  the terminal directly from the control panel. Tokens are only required for
  unauthenticated access via QR codes.

  ## Examples

      # Generate a token for a network
      token = TerminalAuth.generate_token(network_id)

      # Verify a token
      case TerminalAuth.verify_token(token) do
        {:ok, network_id} -> # Token is valid
        {:error, :expired} -> # Token has expired
        {:error, :invalid} -> # Token is invalid
      end
  """

  @salt "terminal_access"
  # 1 hour in seconds
  @max_age 3600
  # 5 minutes grace period for clock skew
  @grace_period 300

  @doc """
  Generates a time-based token for terminal access to a specific network.

  ## Parameters

    * `network_id` - The ID of the network this token grants access to

  ## Returns

    A URL-safe token string

  ## Examples

      iex> TerminalAuth.generate_token("123")
      "SFMyNTY..."
  """
  def generate_token(network_id) do
    Phoenix.Token.sign(PanicWeb.Endpoint, @salt, %{
      network_id: to_string(network_id),
      generated_at: System.system_time(:second)
    })
  end

  @doc """
  Verifies a terminal access token.

  ## Parameters

    * `token` - The token to verify

  ## Returns

    * `{:ok, network_id}` - Token is valid, returns the network_id
    * `{:error, :expired}` - Token has expired
    * `{:error, :invalid}` - Token is invalid or malformed

  ## Examples

      iex> TerminalAuth.verify_token(token)
      {:ok, "123"}

      iex> TerminalAuth.verify_token(expired_token)
      {:error, :expired}
  """
  def verify_token(token) do
    case Phoenix.Token.verify(PanicWeb.Endpoint, @salt, token, max_age: @max_age + @grace_period) do
      {:ok, %{network_id: network_id, generated_at: generated_at}} ->
        # Check if token is older than max_age (without grace period)
        age = System.system_time(:second) - generated_at

        if age > @max_age do
          {:error, :expired}
        else
          {:ok, network_id}
        end

      {:error, :expired} ->
        {:error, :expired}

      {:error, _} ->
        {:error, :invalid}
    end
  end

  @doc """
  Generates a terminal URL with an embedded authentication token.

  ## Parameters

    * `network_id` - The ID of the network

  ## Returns

    A full URL string including the authentication token

  ## Examples

      iex> TerminalAuth.generate_terminal_url("123")
      "https://example.com/networks/123/terminal?token=SFMyNTY..."
  """
  def generate_terminal_url(network_id) do
    token = generate_token(network_id)
    PanicWeb.Endpoint.url() <> "/networks/#{network_id}/terminal?token=#{token}"
  end

  @doc """
  Validates a token in a LiveView socket.

  This is a convenience function for use in LiveView mount/3 callbacks.
  It extracts the token from params and verifies it matches the network_id.

  Note: This function is typically only needed for unauthenticated access.
  Authenticated users bypass token validation in the Terminal LiveView.

  ## Parameters

    * `params` - The params map from mount/3 or handle_params/3
    * `socket` - The LiveView socket

  ## Returns

    * `{:ok, socket}` - Token is valid, socket is unchanged
    * `{:error, socket}` - Token is invalid/expired, socket has redirect

  ## Examples

      def mount(params, _session, socket) do
        # Check if user is authenticated first
        if socket.assigns[:current_user] do
          {:ok, socket}
        else
          case TerminalAuth.validate_token_in_socket(params, socket) do
            {:ok, socket} ->
              {:ok, socket}
            {:error, socket} ->
              {:ok, socket}
          end
        end
      end
  """
  def validate_token_in_socket(%{"network_id" => network_id, "token" => token}, socket) do
    case verify_token(token) do
      {:ok, token_network_id} when token_network_id == network_id ->
        {:ok, socket}

      {:ok, _different_network_id} ->
        # Token is for a different network
        {:error, Phoenix.LiveView.push_navigate(socket, to: "/networks/#{network_id}/terminal/expired")}

      {:error, :expired} ->
        {:error, Phoenix.LiveView.push_navigate(socket, to: "/networks/#{network_id}/terminal/expired")}

      {:error, :invalid} ->
        {:error, Phoenix.LiveView.push_navigate(socket, to: "/networks/#{network_id}/terminal/expired")}
    end
  end

  def validate_token_in_socket(%{"network_id" => network_id}, socket) do
    # No token provided
    {:error, Phoenix.LiveView.push_navigate(socket, to: "/networks/#{network_id}/terminal/expired")}
  end

  def validate_token_in_socket(_params, socket) do
    # Missing required params
    {:error, Phoenix.LiveView.push_navigate(socket, to: "/404")}
  end

  @doc """
  Checks if a token will expire soon (within the next 10 minutes).

  Useful for determining when to refresh a QR code.

  ## Parameters

    * `token` - The token to check

  ## Returns

    * `true` - Token will expire within 10 minutes
    * `false` - Token has more than 10 minutes remaining or is invalid

  ## Examples

      iex> TerminalAuth.expires_soon?(recent_token)
      false

      iex> TerminalAuth.expires_soon?(old_token)
      true
  """
  def expires_soon?(token) do
    case Phoenix.Token.verify(PanicWeb.Endpoint, @salt, token, max_age: @max_age + @grace_period) do
      {:ok, %{generated_at: generated_at}} ->
        # Check if token will expire within the next 10 minutes
        age = System.system_time(:second) - generated_at
        age > @max_age - 600

      {:error, _} ->
        true
    end
  end
end
