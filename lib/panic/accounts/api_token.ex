defmodule Panic.Accounts.ApiToken do
  use Ash.Resource,
    domain: Panic.Accounts,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "api_tokens"
    repo Panic.Repo
  end

  attributes do
    attribute :name, :atom do
      constraints one_of: [
                    :replicate,
                    :openai,
                    :vestaboard_panic_1,
                    :vestaboard_panic_2,
                    :vestaboard_panic_3,
                    :vestaboard_panic_4
                  ]

      primary_key? true
      allow_nil? false
    end

    attribute :value, :string do
      allow_nil? false
    end
  end

  actions do
    defaults [:read, :destroy, update: [:name, :value]]

    create :create do
      accept [:name, :value]
      change relate_actor(:user)
    end
  end

  relationships do
    belongs_to :user, Panic.Accounts.User, allow_nil?: false
  end
end
