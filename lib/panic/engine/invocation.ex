defmodule Panic.Engine.Invocation do
  @moduledoc """
  A resource representing a specific "inference" run for a single model

  The resource includes both the input (prompt) an the output (prediction)
  along with some other metadata.

  ## How a run progresses

  `:start_run` creates the first invocation of a run (the "genesis"), records
  the run on its network and schedules the `:invoke` trigger for it. When an
  invocation completes, it emits `:invocation_completed`, which this resource
  listens to with `:prepare_next`: that creates the next invocation and
  schedules its trigger at `invoke_after`. The trigger only runs while the
  invocation is still part of its network's current run, so stopping or
  replacing a run cancels whatever is pending. See `Panic.Engine.Signals` for
  everything else that listens.
  """
  use Ash.Resource,
    domain: Panic.Engine,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    extensions: [AshOban]

  alias Panic.Engine.Network
  alias Panic.Engine.Signals

  sqlite do
    table "invocations"
    repo Panic.Repo
  end

  resource do
    plural_name :invocations
  end

  oban do
    triggers do
      trigger :invoke do
        action :invoke
        queue :invocations
        scheduler_cron false
        max_attempts 2
        on_error :mark_as_failed
        worker_module_name Panic.Engine.Invocation.InvokeWorker
        scheduler_module_name Panic.Engine.Invocation.InvokeScheduler
        where expr(state in [:ready, :invoking] and run_number == network.current_run_number)
      end
    end
  end

  actions do
    defaults [:read, :destroy]

    create :start_run do
      accept [:input]

      argument :network, :struct do
        constraints instance_of: Network
        allow_nil? false
      end

      emit Signals, :run_started, dynamic?: true
      change Panic.Engine.Changes.StartRun
    end

    create :prepare_next do
      accept [:run_number, :input]
      argument :network_id, :integer, allow_nil?: false
      argument :previous_sequence_number, :integer, allow_nil?: false

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

    update :about_to_invoke do
      change set_attribute(:state, :invoking)
    end

    update :invoke do
      # Model invocation happens in before_transaction to minimize DB contention
      require_atomic? false
      emit Signals, :invocation_completed, dynamic?: true
      emit Signals, :invocation_failed, dynamic?: true
      change Panic.Engine.Changes.InvokeModel
    end

    # Marks an invocation as failed by setting its state to :failed.
    # This does not cancel any running processes, it only updates the database state.
    update :mark_as_failed do
      change set_attribute(:state, :failed)
      emit Signals, :invocation_failed, fields: [invocation_id: :id]
    end

    read :current_run_head do
      argument :run_number, :integer, allow_nil?: false
      get? true
      filter expr(run_number == ^arg(:run_number))
      prepare build(sort: [sequence_number: :desc], limit: 1)
    end

    action :archive_output do
      argument :signal, Signals.InvocationCompleted, allow_nil?: false
      run Panic.Engine.Actions.ArchiveOutput
    end
  end

  policies do
    bypass AshOban.Checks.AshObanInteraction do
      authorize_if always()
    end

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

    policy action(:archive_output) do
      authorize_if actor_present()
    end
  end

  pub_sub do
    module PanicWeb.Endpoint
    prefix "invocation"
    publish_all :create, [:network_id]
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

    # when the :invoke trigger is scheduled to run this invocation
    attribute :invoke_after, :utc_datetime_usec

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :network, Network, allow_nil?: false
  end

  signals_in do
    from Signals do
      on :invocation_completed, :prepare_next,
        inputs: [
          :network_id,
          :run_number,
          input: :output,
          previous_sequence_number: :sequence_number
        ]

      on :invocation_completed, :archive_output, delivery: {AshOban.Signals, queue: :archiver, max_attempts: 3}
    end
  end

  identities do
    identity :unique_in_run, [:network_id, :run_number, :sequence_number]
  end
end
