defmodule Panic.Accounts.APIToken do
  @moduledoc """
  Represents a set of API tokens for various platforms.

  Tokens can be owned by multiple users (many-to-many relationship).
  """

  use Ash.Resource,
    otp_app: :panic,
    domain: Panic.Accounts,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  pub_sub do
    module PanicWeb.Endpoint
    prefix "api_token"

    publish_all :create, ["created"]
    publish_all :update, ["updated"]
    publish_all :destroy, ["destroyed"]
  end

  sqlite do
    table "api_tokens"
    repo Panic.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :name,
        :replicate_token,
        :openai_token,
        :gemini_token,
        :vestaboard_panic_1_token,
        :vestaboard_panic_2_token,
        :vestaboard_panic_3_token,
        :vestaboard_panic_4_token
      ]
    end

    update :update do
      primary? true

      accept [
        :name,
        :replicate_token,
        :openai_token,
        :gemini_token,
        :vestaboard_panic_1_token,
        :vestaboard_panic_2_token,
        :vestaboard_panic_3_token,
        :vestaboard_panic_4_token
      ]
    end

    destroy :destroy do
      primary? true
    end
  end

  attributes do
    integer_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      description "A descriptive name for this token set"
    end

    # Platform tokens
    attribute :replicate_token, :string do
      sensitive? true
      public? true
      description "API token for Replicate platform"
    end

    attribute :openai_token, :string do
      sensitive? true
      public? true
      description "API token for OpenAI platform"
    end

    attribute :gemini_token, :string do
      sensitive? true
      public? true
      description "API token for Google Gemini platform"
    end

    # Vestaboard tokens
    attribute :vestaboard_panic_1_token, :string do
      sensitive? true
      public? true
      description "API token for Vestaboard display #1"
    end

    attribute :vestaboard_panic_2_token, :string do
      sensitive? true
      public? true
      description "API token for Vestaboard display #2"
    end

    attribute :vestaboard_panic_3_token, :string do
      sensitive? true
      public? true
      description "API token for Vestaboard display #3"
    end

    attribute :vestaboard_panic_4_token, :string do
      sensitive? true
      public? true
      description "API token for Vestaboard display #4"
    end

    timestamps()
  end

  relationships do
    many_to_many :users, Panic.Accounts.User do
      through Panic.Accounts.UserAPIToken
      source_attribute :id
      destination_attribute :id
    end
  end

  policies do
    # Allow users to read and manage tokens they own
    policy action_type(:read) do
      authorize_if relates_to_actor_via(:users)
    end

    # For create, just check that there's an actor
    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action_type([:update, :destroy]) do
      authorize_if relates_to_actor_via(:users)
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
  end
end
