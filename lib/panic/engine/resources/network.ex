defmodule Panic.Engine.Network do
  @moduledoc """
  A Network represents a specific network (i.e. cyclic graph) of models.
  """

  use Ash.Resource,
    domain: Panic.Engine,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Panic.Workers.Invoker

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

    # :models is an array of strings - each one corresponding to the :id of a known %Pamic.Model{}
    attribute :models, {:array, :string} do
      default []
      allow_nil? false
    end

    attribute :slug, :string
    create_timestamp :inserted_at
    update_timestamp :updated_at
    # attribute :schedule
    # attribute :backoff
  end

  actions do
    defaults [:read, :destroy, update: [:name, :description]]

    create :create do
      accept [:name, :description]
      set_attribute(:models, [])
      change relate_actor(:user)
    end

    update :update_models do
      accept [:models]
      validate Panic.Validations.ModelIOConnections
    end

    action :start_run, :term do
      argument :first_invocation, :struct do
        constraints instance_of: Panic.Engine.Invocation
        allow_nil? false
      end

      run fn input, context ->
        Invoker.insert(input.arguments.first_invocation, context.actor)
      end
    end

    action :stop_run do
      argument :network_id, :integer, allow_nil?: false

      run fn input, _context ->
        Invoker.cancel_running_jobs(input.arguments.network_id)
      end
    end
  end

  relationships do
    belongs_to :user, Panic.Accounts.User, allow_nil?: false
  end

  policies do
    # this is for the :start_run action for now
    # perhaps find a better way to authorize
    policy action_type(:action) do
      authorize_if always()
    end

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
