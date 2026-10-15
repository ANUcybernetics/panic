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
        # accounts are created by an operator (Panic.Release), not by visitors
        registration_enabled? false
      end

      api_key :api_key do
        api_key_relationship :valid_api_keys
        api_key_hash_attribute :api_key_hash
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

    update :set_admin do
      accept [:admin]
    end

    read :sign_in_with_password do
      description "Attempt to sign in using a email and password."
      get? true

      argument :email, :ci_string do
        description "The email to use for retrieving the user."
        allow_nil? false
      end

      argument :password, :string do
        description "The password to check for the matching user."
        allow_nil? false
        sensitive? true
      end

      # validates the provided email and password and generates a token
      prepare AshAuthentication.Strategy.Password.SignInPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    create :register_with_password do
      description "Register a new user with a email and password."

      argument :email, :ci_string do
        allow_nil? false
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 8
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      change set_attribute(:email, arg(:email))
      change AshAuthentication.Strategy.Password.HashPasswordChange
      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation
    end

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    read :sign_in_with_api_key do
      argument :api_key, :string, allow_nil?: false
      prepare AshAuthentication.Strategy.ApiKey.SignInPreparation
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    # creating and destroying users is left to operators (authorize?: false)
    policy action_type(:read) do
      authorize_if expr(id == ^actor(:id))
    end

    policy action(:set_admin) do
      authorize_if actor_attribute_equals(:admin, true)
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

    has_many :valid_api_keys, Panic.Accounts.ApiKey do
      filter expr(valid)
    end
  end

  identities do
    identity :unique_email, [:email]
  end
end
