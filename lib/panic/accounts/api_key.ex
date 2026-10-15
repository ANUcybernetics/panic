defmodule Panic.Accounts.ApiKey do
  @moduledoc """
  A key for the JSON API (`/api`), owned by the admin who created it.

  Only a hash is stored: the plaintext key is in
  `api_key.__metadata__.plaintext_api_key` immediately after `:create` and
  nowhere else. Keys without `expires_at` never expire.
  """
  use Ash.Resource,
    otp_app: :panic,
    domain: Panic.Accounts,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  sqlite do
    table "api_keys"
    repo Panic.Repo

    references do
      reference :user, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :expires_at]
      change relate_actor(:user)

      change {AshAuthentication.Strategy.ApiKey.GenerateApiKey, prefix: :panic, hash: :api_key_hash}
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy action_type(:create) do
      authorize_if actor_attribute_equals(:admin, true)
    end

    policy action_type([:read, :destroy]) do
      authorize_if relates_to_actor_via(:user)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :api_key_hash, :binary do
      allow_nil? false
      sensitive? true
    end

    attribute :expires_at, :utc_datetime_usec, public?: true

    create_timestamp :inserted_at, public?: true
  end

  relationships do
    belongs_to :user, Panic.Accounts.User, allow_nil?: false
  end

  calculations do
    calculate :valid, :boolean, expr(is_nil(expires_at) or expires_at > now())
  end

  identities do
    identity :unique_api_key, [:api_key_hash]
  end
end
