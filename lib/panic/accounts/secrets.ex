# ABOUTME: Implements secret retrieval for AshAuthentication tokens
# ABOUTME: Fetches the secret_key_base from the PanicWeb.Endpoint configuration
defmodule Panic.Accounts.Secrets do
  @moduledoc false
  use AshAuthentication.Secret

  def secret_for([:authentication, :tokens, :signing_secret], Panic.Accounts.User, _opts, _context) do
    case Application.fetch_env(:panic, PanicWeb.Endpoint) do
      {:ok, endpoint_config} ->
        Keyword.fetch(endpoint_config, :secret_key_base)

      :error ->
        :error
    end
  end
end
