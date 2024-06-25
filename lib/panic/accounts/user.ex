defmodule Panic.Accounts.User do
  use Ash.Resource,
    data_layer: AshSqlite.DataLayer,
    extensions: [AshAuthentication],
    # authorizers: [Ash.Policy.Authorizer],
    domain: Panic.Accounts

  attributes do
    integer_primary_key :id
    attribute :email, :ci_string, allow_nil?: false, public?: true
    attribute :hashed_password, :string, allow_nil?: false, sensitive?: true
  end

  actions do
    update :set_api_token do
      argument :token_name, :atom, allow_nil?: false
      argument :token_value, :string, allow_nil?: false
      change TODO
    end
  end

  authentication do
    strategies do
      password :password do
        identity_field :email
      end
    end

    tokens do
      enabled? true
      token_resource Panic.Accounts.Token

      signing_secret fn _, _ ->
        Application.fetch_env(:panic, :token_signing_secret)
      end
    end
  end

  sqlite do
    table "users"
    repo Panic.Repo
  end

  identities do
    identity :unique_email, [:email]
  end

  relationships do
    has_many :api_tokens, Panic.Accounts.ApiToken
  end

  # You can customize this if you wish, but this is a safe default that
  # only allows user data to be interacted with via AshAuthentication.
  # policies do
  #   bypass AshAuthentication.Checks.AshAuthenticationInteraction do
  #     authorize_if always()
  #   end

  #   policy always() do
  #     forbid_if always()
  #   end
  # end
end
