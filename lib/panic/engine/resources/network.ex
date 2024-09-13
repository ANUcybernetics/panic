defmodule Panic.Engine.Network do
  @moduledoc """
  A Network represents a specific network (i.e. cyclic graph) of models.
  """

  use Ash.Resource,
    domain: Panic.Engine,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

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

    attribute :state, :atom do
      default :stopped

      # `:starting` represents the initial "uninterruptible" period
      constraints one_of: [:starting, :running, :paused, :stopped]
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

    update :append_model do
      # describe("Append a model to the end of the list of models")
      argument :model_id, :string, allow_nil?: false

      change fn changeset, _ ->
        models = changeset.data.models ++ [Ash.Changeset.get_argument(changeset, :model_id)]
        Ash.Changeset.force_change_attribute(changeset, :models, models)
      end
    end

    action :start_run do
      argument :first_invocation, :struct do
        constraints instance_of: Panic.Engine.Invocation
        allow_nil? false
      end

      run fn input, context ->
        invocation = Panic.Engine.invoke!(input.arguments.first_invocation, actor: context.actor)
        :ok
      end
    end

    # update :drop_model
    # update :swap_model
    # action :start_run
    # read :statistics
    # read :state
    # update :set_state
    # create :duplicate # duplicate the network

    update :set_state do
      argument :state, :atom, allow_nil?: false
      change atomic_update(:state, arg(:state))
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
