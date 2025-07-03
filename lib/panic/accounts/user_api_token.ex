defmodule Panic.Accounts.UserAPIToken do
  @moduledoc """
  Join table for the many-to-many relationship between Users and APITokens.
  """
  
  use Ash.Resource,
    otp_app: :panic,
    domain: Panic.Accounts,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "user_api_tokens"
    repo Panic.Repo
  end

  actions do
    defaults [:read, :destroy]
    
    create :create do
      primary? true
      upsert? true
      accept [:user_id, :api_token_id]
    end
  end

  attributes do
    integer_primary_key :id
    timestamps()
  end

  relationships do
    belongs_to :user, Panic.Accounts.User do
      allow_nil? false
      attribute_type :integer
    end

    belongs_to :api_token, Panic.Accounts.APIToken do
      allow_nil? false
      attribute_type :integer
    end
  end
end