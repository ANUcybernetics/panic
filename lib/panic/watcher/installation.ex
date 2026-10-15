defmodule Panic.Watcher.Installation do
  @moduledoc """
  An Installation represents a collection of display configurations that observe invocations from a network.

  Each installation belongs to a network and contains an array of configs that define
  how invocations should be displayed (grid, single, or vestaboard format).

  ## Examples

      # Create an installation with a grid config
      Ash.create!(Installation, %{
        name: "Main Display",
        network_id: network.id,
        configs: [
          %{type: :grid, rows: 2, columns: 3}
        ]
      })

      # Add a single config to an existing installation
      installation
      |> Ash.Changeset.for_update(:add_config, %{
        config: %{type: :single, stride: 3, offset: 0}
      })
      |> Ash.update!()
  """
  use Ash.Resource,
    otp_app: :panic,
    domain: Panic.Watcher,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    extensions: [AshJsonApi.Resource]

  alias Panic.Engine.Network
  alias Panic.Engine.Signals
  alias Panic.Watcher.Actions.UpdateVestaboards
  alias Panic.Watcher.Installation.Config

  sqlite do
    table "installations"
    repo Panic.Repo
  end

  json_api do
    type "installation"
  end

  resource do
    plural_name :installations
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :watchers]
      argument :network_id, :integer, allow_nil?: false

      change manage_relationship(:network_id, :network, type: :append_and_remove)
    end

    update :update do
      accept [:name, :watchers]
      argument :network_id, :integer, allow_nil?: true
      require_atomic? false

      change manage_relationship(:network_id, :network, type: :append_and_remove)
    end

    update :add_watcher do
      argument :watcher, Config, allow_nil?: false
      require_atomic? false

      change Panic.Watcher.Changes.AddWatcher
    end

    update :remove_watcher do
      argument :watcher_name, :string, allow_nil?: false
      require_atomic? false

      change Panic.Watcher.Changes.RemoveWatcher
    end

    update :update_watcher do
      argument :watcher_name, :string, allow_nil?: false
      argument :updated_watcher, Config, allow_nil?: false
      require_atomic? false

      change Panic.Watcher.Changes.UpdateWatcher
    end

    update :reorder_watchers do
      accept [:watchers]
      require_atomic? false
    end

    action :show_initial_prompt do
      argument :signal, Signals.RunStarted, allow_nil?: false
      run UpdateVestaboards
    end

    action :show_output do
      argument :signal, Signals.InvocationCompleted, allow_nil?: false
      run UpdateVestaboards
    end
  end

  policies do
    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action_type([:read, :update, :destroy]) do
      authorize_if relates_to_actor_via([:network, :user])
    end

    policy action([:show_initial_prompt, :show_output]) do
      authorize_if actor_present()
    end
  end

  pub_sub do
    module PanicWeb.Endpoint
    prefix "installation"
    publish_all :update, [:id]
  end

  validations do
    validate Panic.Watcher.Validations.UniqueWatcherNames
  end

  attributes do
    integer_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :watchers, {:array, Config} do
      default []
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at, public?: true
    update_timestamp :updated_at, public?: true
  end

  relationships do
    belongs_to :network, Network do
      allow_nil? false
      public? true
      attribute_public? true
    end
  end

  # Vestaboards are slow, rate limited and external, so they're driven from a
  # single-concurrency job queue rather than inside the engine's transaction.
  signals_in do
    from Signals do
      on :run_started, :show_initial_prompt, delivery: {AshOban.Signals, queue: :vestaboards, max_attempts: 2}

      on :invocation_completed, :show_output, delivery: {AshOban.Signals, queue: :vestaboards, max_attempts: 2}
    end
  end
end
