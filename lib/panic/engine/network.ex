defmodule Panic.Engine.Network do
  @moduledoc """
  A Network represents a specific network (i.e. cyclic graph) of models.
  """

  use Ash.Resource,
    domain: Panic.Engine,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    extensions: [AshJsonApi.Resource]

  alias Panic.Engine.Invocation
  alias Panic.Engine.Signals

  sqlite do
    table "networks"
    repo Panic.Repo
  end

  json_api do
    type "network"
  end

  resource do
    plural_name :networks
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

    # set by Invocation :start_run, in the same transaction as the genesis invocation
    update :begin_run do
      accept [:current_run_number, :run_started_at]
    end

    read :running do
      filter expr(not is_nil(current_run_number))
    end

    update :stop_run do
      change set_attribute(:current_run_number, nil)
      change set_attribute(:run_started_at, nil)
    end

    # listens to :invocation_failed for the network's current run
    update :end_run do
      change set_attribute(:current_run_number, nil)
      change set_attribute(:run_started_at, nil)
    end

    action :start_run, :struct do
      description "Start a run with the given input, replacing the current run unless it's locked out."
      constraints instance_of: __MODULE__
      argument :id, :integer, allow_nil?: false
      argument :input, :string, allow_nil?: false
      run Panic.Engine.Actions.StartNetworkRun
    end

    action :list_models, {:array, :map} do
      description "Every model a network can use, with its input and output types."
      run Panic.Engine.Actions.ListModels
    end
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

    # :start_run reads the network with the actor, so only its owner gets through
    policy action([:start_run, :list_models]) do
      authorize_if actor_present()
    end
  end

  # lets viewers of a network see runs start and stop
  pub_sub do
    module PanicWeb.Endpoint
    prefix "network"
    publish_all :update, [:id]
  end

  attributes do
    integer_primary_key :id

    # attribute :owner
    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string, public?: true

    # :models is an ordered array of model id strings
    attribute :models, {:array, :string} do
      default []
      allow_nil? false
      public? true
    end

    attribute :lockout_seconds, :integer do
      default 30
      allow_nil? false
      public? true
    end

    # the run_number (genesis invocation id) of the run in progress, nil when idle
    attribute :current_run_number, :integer, public?: true
    attribute :run_started_at, :utc_datetime_usec, public?: true

    create_timestamp :inserted_at, public?: true
    update_timestamp :updated_at, public?: true
    # attribute :schedule
    # attribute :backoff
  end

  relationships do
    belongs_to :user, Panic.Accounts.User, allow_nil?: false
    has_many :invocations, Invocation, public?: true
    has_many :installations, Panic.Watcher.Installation, public?: true
  end

  signals_in do
    from Signals do
      on :invocation_failed, :end_run, get_by: [id: :network_id, current_run_number: :run_number]
    end
  end
end
