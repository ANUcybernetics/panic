defmodule Panic.Secrets do
  @moduledoc false
  use AshAuthentication.Secret

  def secret_for([:authentication, :tokens, :signing_secret], Panic.Accounts.User, _opts, _context) do
    case Application.fetch_env(:panic, :token_signing_secret) do
      {:ok, secret} -> {:ok, secret}
      :error -> :error
    end
  end
end
