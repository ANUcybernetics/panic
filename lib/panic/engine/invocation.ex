defmodule Panic.Engine.Invocation do
  @moduledoc """
  A resource representing a specific "inference" run for a single model

  The resource includes both the input (prompt) an the output (prediction)
  along with some other metadata.
  """
  use Ash.Resource,
    domain: Panic.Engine,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  alias Panic.Engine.Network

  sqlite do
    table "invocations"
    repo Panic.Repo
  end

  resource do
    plural_name :invocations
  end

  actions do
    defaults [:read, :destroy]

    # TODO could this be a calculation/aggregate
    read :most_recent do
      argument :network_id, :integer
      filter expr(network_id == ^arg(:network_id))
      prepare build(sort: [updated_at: :desc], limit: 1)
      get? true
    end

    read :list_run do
      argument :network_id, :integer, allow_nil?: false
      argument :run_number, :integer, allow_nil?: false
      prepare build(sort: [sequence_number: :asc])
      filter expr(network_id == ^arg(:network_id) and run_number == ^arg(:run_number))
    end

    read :current_run do
      argument :network_id, :integer, allow_nil?: false
      argument :limit, :integer, default: 100
      prepare build(sort: [sequence_number: :asc], limit: arg(:limit))

      # FIXME make sure this is done with a db index (perhaps via an identity?) for performance reasons
      filter expr(
               network_id == ^arg(:network_id) and
                 run_number ==
                   fragment(
                     "SELECT MAX(run_number) FROM invocations WHERE network_id = ?",
                     ^arg(:network_id)
                   ) and
                 state == :completed
             )
    end

    # maybe "prepare"?
    create :prepare_first do
      accept [:input]

      argument :network, :struct do
        constraints instance_of: Network
        allow_nil? false
      end

      change Panic.Engine.Changes.PrepareFirst
    end

    create :prepare_next do
      argument :previous_invocation, :struct do
        constraints instance_of: __MODULE__
        allow_nil? false
      end

      change Panic.Engine.Changes.PrepareNext
    end

    update :set_run_number do
      accept [:run_number]
    end

    update :update_input do
      accept [:input]
    end

    update :update_output do
      accept [:output]
    end

    # this is here because :about_to_invoke now pauses to run the vestaboards,
    # which is fine _except_ for the first invocation where we need the first one
    # to come trhoguh and set the genesis, start the lockout timer, etc.

    update :about_to_invoke do
      change set_attribute(:state, :invoking)
    end

    update :invoke do
      # Model invocation happens in before_transaction to minimize DB contention
      require_atomic? false
      change Panic.Engine.Changes.InvokeModel
    end

    # Marks an invocation as failed by setting its state to :failed.
    # This does not cancel any running processes, it only updates the database state.
    update :mark_as_failed do
      change set_attribute(:state, :failed)
    end
  end

  policies do
    policy action_type(:create) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if relates_to_actor_via([:network, :user])
    end

    policy action(:set_run_number) do
      authorize_if always()
    end

    policy action_type(:update) do
      authorize_if relates_to_actor_via([:network, :user])
    end

    policy action_type(:destroy) do
      authorize_if relates_to_actor_via([:network, :user])
    end
  end

  pub_sub do
    module PanicWeb.Endpoint
    prefix "invocation"
    publish_all :update, [:network_id]
  end

  attributes do
    integer_primary_key :id

    attribute :input, :string, allow_nil?: false

    attribute :state, :atom do
      constraints one_of: [:ready, :invoking, :completed, :failed]
      allow_nil? false
      default :ready
    end

    attribute :model, :string, allow_nil?: false
    attribute :metadata, :map, allow_nil?: false, default: %{}
    attribute :output, :string

    attribute :sequence_number, :integer do
      constraints min: 0
      allow_nil? false
    end

    attribute :run_number, :integer do
      constraints min: 0
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :network, Network, allow_nil?: false
  end

  identities do
    identity :unique_in_run, [:network_id, :run_number, :sequence_number]
  end
end
