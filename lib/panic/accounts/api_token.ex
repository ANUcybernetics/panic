defmodule Panic.Accounts.ApiToken do
  use Ash.Resource,
    domain: Panic.Accounts,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  sqlite do
    table "api_tokens"
    repo Panic.Repo
  end

  attributes do
    integer_primary_key :id

    attribute :name, :atom do
      constraints one_of: [
                    :replicate,
                    :openai,
                    :vestaboard_panic_1,
                    :vestaboard_panic_2,
                    :vestaboard_panic_3,
                    :vestaboard_panic_4
                  ]

      allow_nil? false
    end

    attribute :value, :string do
      allow_nil? false
    end
  end

  actions do
    defaults [:read, :destroy, :update]

    create :create do
      primary? true
      accept [:name, :value]
      change relate_actor(:user)
    end

    read :get_by_name do
      argument :name, :atom
      get? true
      filter expr(name == ^arg(:name))
    end
  end

  identities do
    identity :token, [:name, :user_id]
  end

  relationships do
    belongs_to :user, Panic.Accounts.User, allow_nil?: false
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via(:user)
      # authorize_if actor_present()
    end

    policy action_type(:create) do
      authorize_if actor_present()
    end
  end
end
