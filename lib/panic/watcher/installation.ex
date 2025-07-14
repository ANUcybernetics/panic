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
    notifiers: [Ash.Notifier.PubSub]

  alias Panic.Engine.Network
  alias Panic.Watcher.Installation.Config

  attributes do
    integer_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    attribute :watchers, {:array, Config} do
      default []
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :network, Network do
      allow_nil? false
    end
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
  end

  validations do
    validate Panic.Watcher.Validations.UniqueWatcherNames
  end

  policies do
    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action_type([:read, :update, :destroy]) do
      authorize_if relates_to_actor_via([:network, :user])
    end
  end

  resource do
    plural_name :installations
  end

  pub_sub do
    module PanicWeb.Endpoint
    prefix "installation"
    publish_all :update, [:id]
  end

  sqlite do
    table "installations"
    repo Panic.Repo
  end
end
