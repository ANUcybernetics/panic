defmodule Panic.Engine.Network do
  @moduledoc """
  A Network represents a specific network (i.e. cyclic graph) of models.
  """

  use Ash.Resource,
    domain: Panic.Engine,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Panic.Engine.Invocation
  alias Panic.Engine.NetworkRunner

  sqlite do
    table "networks"
    repo Panic.Repo
  end

  resource do
    plural_name :networks
  end

  attributes do
    integer_primary_key :id

    # attribute :owner
    attribute :name, :string do
      allow_nil? false
    end

    attribute :description, :string

    # :models is an ordered array of model id strings
    attribute :models, {:array, :string} do
      default []
      allow_nil? false
    end

    attribute :slug, :string

    attribute :lockout_seconds, :integer do
      default 30
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
    # attribute :schedule
    # attribute :backoff
  end

  actions do
    defaults [:read, update: [:name, :description, :lockout_seconds]]

    destroy :destroy do
      primary? true
      # Use before-action hooks to delete children before parent (required for FK constraints)
      change cascade_destroy(:invocations, after_action?: false)
      change cascade_destroy(:installations, after_action?: false)
    end

    create :create do
      accept [:name, :description, :lockout_seconds]
      set_attribute(:models, [])
      change relate_actor(:user)
    end

    update :update_models do
      accept [:models]
      validate Panic.Validations.ModelIOConnections
      require_atomic? false
    end

    action :stop_run do
      argument :network_id, :integer, allow_nil?: false

      run fn input, _context ->
        NetworkRunner.stop_run(input.arguments.network_id)
      end
    end
  end

  relationships do
    belongs_to :user, Panic.Accounts.User, allow_nil?: false
    has_many :invocations, Invocation
    has_many :installations, Panic.Watcher.Installation
  end

  policies do
    policy action_type(:create) do
      authorize_if relating_to_actor(:user)
    end

    policy action_type(:read) do
      authorize_if relates_to_actor_via(:user)
    end

    policy action_type(:update) do
      authorize_if relates_to_actor_via(:user)
    end

    policy action_type(:destroy) do
      authorize_if relates_to_actor_via(:user)
    end
  end
end
