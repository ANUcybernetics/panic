defmodule Panic.Engine.Installation do
  @moduledoc """
  An Installation represents a collection of watchers that display invocations from a network.

  Each installation belongs to a network and contains an array of watchers that define
  how invocations should be displayed (grid, single, or vestaboard format).

  ## Examples

      # Create an installation with a grid watcher
      Ash.create!(Installation, %{
        name: "Main Display",
        network_id: network.id,
        watchers: [
          %{type: :grid, rows: 2, columns: 3}
        ]
      })

      # Add a single watcher to an existing installation
      installation
      |> Ash.Changeset.for_update(:add_watcher, %{
        watcher: %{type: :single, stride: 3, offset: 0}
      })
      |> Ash.update!()
  """
  use Ash.Resource,
    otp_app: :panic,
    domain: Panic.Engine,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  alias Panic.Engine.Installation.Watcher
  alias Panic.Engine.Network

  attributes do
    integer_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    attribute :watchers, {:array, Watcher} do
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
      argument :watcher, Watcher, allow_nil?: false
      require_atomic? false

      change Panic.Engine.Changes.AddWatcher
    end

    update :remove_watcher do
      argument :index, :integer, allow_nil?: false
      require_atomic? false

      change Panic.Engine.Changes.RemoveWatcher
    end

    update :update_watcher do
      argument :index, :integer, allow_nil?: false
      argument :watcher, Watcher, allow_nil?: false
      require_atomic? false

      change Panic.Engine.Changes.UpdateWatcher
    end

    update :reorder_watchers do
      accept [:watchers]
      require_atomic? false
    end
  end

  validations do
    validate Panic.Engine.Validations.UniqueWatcherNames
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
