defmodule PanicWeb.TerminalAuth do
  @moduledoc """
  Tokens for the anonymous terminal: the QR code on the first screen of each
  of a network's installations opens a terminal that anyone can prompt the
  network from, without signing in, for the network's `anon_terminal_minutes`
  (subject to the network's lockout, like any other run).

  The token carries the time it was issued, and the terminal closes that many
  minutes later. The displays issue a fresh token every `qr_refresh_ms/0`, so
  a scan gives (almost) the full time, but a photo of an old QR code soon
  stops working: the terminal is for people who are at the installation.

  A network with `anon_terminal_minutes` set to nil has no anonymous
  terminal, and its tokens don't verify. Signed-in users don't need a token.
  """

  alias Panic.Engine.Network

  @salt "anon_terminal"
  @qr_refresh_ms to_timeout(minute: 1)

  @doc """
  How often a display should show a new QR code.
  """
  def qr_refresh_ms, do: @qr_refresh_ms

  @doc """
  The URL of an anonymous terminal for the network, issued now.
  """
  def terminal_url(network_id) do
    PanicWeb.Endpoint.url() <> "/networks/#{network_id}/terminal?token=#{token(network_id)}"
  end

  @doc """
  A terminal token for the network, issued at `issued_at` (unix seconds).

  It's the issue time and a signature of it and the network id: short, so
  the QR code stays coarse enough to scan from across a room.
  """
  def token(network_id, issued_at \\ System.system_time(:second)) do
    "#{issued_at}.#{signature(network_id, issued_at)}"
  end

  @doc """
  Verifies a terminal token for the network, returning when the terminal it
  opens closes.
  """
  def verify(_token, %Network{anon_terminal_minutes: nil}), do: {:error, :disabled}

  def verify(token, %Network{id: id, anon_terminal_minutes: minutes}) when is_binary(token) do
    with [issued, signature] <- String.split(token, "."),
         {issued_at, ""} <- Integer.parse(issued),
         true <- Plug.Crypto.secure_compare(signature, signature(id, issued_at)) do
      expires_at = issued_at + minutes * 60
      now = System.system_time(:second)

      # a token from the future would stay open too long
      if issued_at <= now and now <= expires_at,
        do: {:ok, DateTime.from_unix!(expires_at)},
        else: {:error, :expired}
    else
      _ -> {:error, :invalid}
    end
  end

  def verify(_token, _network), do: {:error, :invalid}

  # 128 bits of HMAC-SHA256 is plenty for a token that lasts minutes
  defp signature(network_id, issued_at) do
    secret = PanicWeb.Endpoint.config(:secret_key_base)

    :hmac
    |> :crypto.mac(:sha256, secret, "#{@salt}:#{network_id}:#{issued_at}")
    |> binary_part(0, 16)
    |> Base.url_encode64(padding: false)
  end
end
