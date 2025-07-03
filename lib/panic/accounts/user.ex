defmodule Panic.Accounts.User do
  @moduledoc false
  use Ash.Resource,
    data_layer: AshSqlite.DataLayer,
    extensions: [AshAuthentication],
    authorizers: [Ash.Policy.Authorizer],
    domain: Panic.Accounts

  resource do
    plural_name :users
  end

  attributes do
    integer_primary_key :id
    attribute :email, :ci_string, allow_nil?: false, public?: true
    attribute :hashed_password, :string, allow_nil?: false, sensitive?: true
    # attribute :role, :atom do
    #   constraints one_of: [:user, :admin]
    # end
  end

  actions do
    defaults [:read, :destroy]

    update :change_email do
      accept [:email]
    end
  end

  authentication do
    strategies do
      password :password do
        identity_field :email
        sign_in_tokens_enabled? false
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
    many_to_many :api_tokens, Panic.Accounts.APIToken do
      through Panic.Accounts.UserAPIToken
      source_attribute :id
      destination_attribute :id
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    # in future, update this so that only role: admin users can create new users (although)
    # there may still be a bootstrapping problem there?
    policy action_type(:create) do
      authorize_if always()
    end

    # can only read & update User if the actor is the User being updated
    policy_group expr(id == ^actor(:id)) do
      policy action_type(:read), do: authorize_if(always())
      policy action_type(:update), do: authorize_if(always())
    end
  end
end
