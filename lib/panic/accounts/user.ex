defmodule Panic.Accounts.User do
  @moduledoc false
  use Ash.Resource,
    data_layer: AshSqlite.DataLayer,
    extensions: [AshAuthentication],
    authorizers: [Ash.Policy.Authorizer],
    domain: Panic.Accounts

  sqlite do
    table "users"
    repo Panic.Repo
  end

  authentication do
    strategies do
      password :password do
        identity_field :email
        sign_in_tokens_enabled? false
      end
    end

    add_ons do
      log_out_everywhere do
        apply_on_password_change? true
      end
    end

    tokens do
      enabled? true
      token_resource Panic.Accounts.Token
      signing_secret Panic.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end
  end

  resource do
    plural_name :users
  end

  actions do
    defaults [:read, :destroy]

    update :change_email do
      accept [:email]
    end

    # Admin-only action to grant/revoke admin status
    update :set_admin do
      accept [:admin]

      # Only admins can change admin status
      # We'll add a policy for this
    end

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
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

  attributes do
    integer_primary_key :id
    attribute :email, :ci_string, allow_nil?: false, public?: true
    attribute :hashed_password, :string, allow_nil?: false, sensitive?: true

    attribute :admin, :boolean do
      default false
      allow_nil? false
      # Don't expose admin status publicly
      public? false
    end
  end

  relationships do
    many_to_many :api_tokens, Panic.Accounts.APIToken do
      through Panic.Accounts.UserAPIToken
      source_attribute :id
      destination_attribute :id
    end
  end

  identities do
    identity :unique_email, [:email]
  end
end
