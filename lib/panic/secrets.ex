defmodule Panic.Secrets do
  @moduledoc false
  use AshAuthentication.Secret

  def secret_for([:authentication, :tokens, :signing_secret], Panic.Accounts.User, _opts, _context) do
    case Application.fetch_env(:panic, :token_signing_secret) do
      {:ok, secret} ->
        {:ok, secret}

      :error ->
        # Fallback for test environment if config isn't loaded yet
        if Mix.env() == :test do
          {:ok, "lR3r6rkW8nRkChM35qcKl00FNSK95ra5"}
        else
          :error
        end
    end
  end
end
