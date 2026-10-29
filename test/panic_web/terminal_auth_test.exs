defmodule PanicWeb.TerminalAuthTest do
  use ExUnit.Case, async: true

  alias Panic.Engine.Network
  alias PanicWeb.TerminalAuth

  @network %Network{id: 123, anon_terminal_minutes: 10}

  defp minutes_ago(minutes), do: System.system_time(:second) - minutes * 60

  test "a fresh token opens a terminal for the network's minutes" do
    issued_at = System.system_time(:second)
    token = TerminalAuth.token(@network.id, issued_at)

    assert {:ok, expires_at} = TerminalAuth.verify(token, @network)
    assert DateTime.to_unix(expires_at) == issued_at + 10 * 60
  end

  test "a token's terminal closes the network's minutes after it was issued" do
    issued_at = minutes_ago(4)
    token = TerminalAuth.token(@network.id, issued_at)

    assert {:ok, expires_at} = TerminalAuth.verify(token, @network)
    assert DateTime.to_unix(expires_at) == issued_at + 10 * 60
  end

  test "a token older than the network's minutes has expired" do
    token = TerminalAuth.token(@network.id, minutes_ago(11))
    assert {:error, :expired} = TerminalAuth.verify(token, @network)
  end

  test "a token issued in the future doesn't verify" do
    token = TerminalAuth.token(@network.id, minutes_ago(-5))
    assert {:error, :expired} = TerminalAuth.verify(token, @network)
  end

  test "a token whose issue time has been changed doesn't verify" do
    [_issued, signature] = @network.id |> TerminalAuth.token(minutes_ago(11)) |> String.split(".")
    assert {:error, :invalid} = TerminalAuth.verify("#{minutes_ago(1)}.#{signature}", @network)
  end

  test "the network's current setting decides how long a token lasts" do
    token = TerminalAuth.token(@network.id, minutes_ago(11))

    assert {:ok, _expires_at} =
             TerminalAuth.verify(token, %{@network | anon_terminal_minutes: 30})
  end

  test "no token verifies for a network with the anonymous terminal off" do
    token = TerminalAuth.token(@network.id)

    assert {:error, :disabled} =
             TerminalAuth.verify(token, %{@network | anon_terminal_minutes: nil})
  end

  test "a token for another network doesn't verify" do
    token = TerminalAuth.token(456)
    assert {:error, :invalid} = TerminalAuth.verify(token, @network)
  end

  test "malformed and missing tokens don't verify" do
    assert {:error, :invalid} = TerminalAuth.verify("not-a-token", @network)
    assert {:error, :invalid} = TerminalAuth.verify(nil, @network)
  end

  test "a terminal URL points at the network's terminal with a token" do
    url = TerminalAuth.terminal_url(@network.id)

    assert url =~ ~r{^https?://.+/networks/123/terminal\?token=.+}
    [_, token] = String.split(url, "token=")
    assert {:ok, _expires_at} = TerminalAuth.verify(token, @network)
  end
end
