defmodule Panic.Accounts.User do
  use Ash.Resource,
    data_layer: AshSqlite.DataLayer,
    extensions: [AshAuthentication],
    # authorizers: [Ash.Policy.Authorizer],
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

    # API tokens... this could (should?) be a map? oh well, easy to change later
    attribute :replicate_token, :string, sensitive?: true
    attribute :openai_token, :string, sensitive?: true
    attribute :vestaboard_panic_1_token, :string, sensitive?: true
    attribute :vestaboard_panic_2_token, :string, sensitive?: true
    attribute :vestaboard_panic_3_token, :string, sensitive?: true
    attribute :vestaboard_panic_4_token, :string, sensitive?: true
  end

  actions do
    defaults [:read, :destroy]

    update :change_email do
      accept [:email]
    end

    update :set_token do
      argument :token_name, :atom do
        constraints one_of: [
                      :replicate_token,
                      :openai_token,
                      :vestaboard_panic_1_token,
                      :vestaboard_panic_2_token,
                      :vestaboard_panic_3_token,
                      :vestaboard_panic_4_token
                    ]

        allow_nil? false
      end

      argument :token_value, :string, allow_nil?: false, sensitive?: true

      # just a convenience for the fact that there are several tokens, and
      # it's a pain to have an action for setting each one
      change fn changeset, _context ->
        if changeset.valid? do
          {:ok, token_name} = Ash.Changeset.fetch_argument(changeset, :token_name)
          {:ok, token_value} = Ash.Changeset.fetch_argument(changeset, :token_value)
          Ash.Changeset.force_change_attribute(changeset, token_name, token_value)
        else
          changeset
        end
      end
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
