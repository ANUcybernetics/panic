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
    authorizers: [Ash.Policy.Authorizer]

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
    belongs_to :network, Panic.Engine.Network do
      allow_nil? false
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :watchers]
      argument :network_id, :integer, allow_nil?: false

      validate fn changeset, _context ->
        case changeset.arguments[:network_id] do
          nil ->
            :ok

          network_id ->
            case Ash.get(Network, network_id, actor: changeset.context[:private][:actor], authorize?: false) do
              {:ok, network} ->
                if network.user_id == changeset.context[:private][:actor].id do
                  :ok
                else
                  {:error, field: :network_id, message: "does not belong to you"}
                end

              {:error, _} ->
                {:error, field: :network_id, message: "not found"}
            end
        end
      end

      change manage_relationship(:network_id, :network, type: :append_and_remove)
    end

    update :update do
      accept [:name, :watchers]
    end

    update :add_watcher do
      argument :watcher, Watcher, allow_nil?: false

      change fn changeset, _context ->
        current_watchers = Ash.Changeset.get_attribute(changeset, :watchers) || []
        watcher = Ash.Changeset.get_argument(changeset, :watcher)
        new_watchers = current_watchers ++ [watcher]
        Ash.Changeset.change_attribute(changeset, :watchers, new_watchers)
      end
    end

    update :remove_watcher do
      argument :index, :integer, allow_nil?: false

      change fn changeset, _context ->
        current_watchers = Ash.Changeset.get_attribute(changeset, :watchers) || []
        index = Ash.Changeset.get_argument(changeset, :index)
        new_watchers = List.delete_at(current_watchers, index)
        Ash.Changeset.change_attribute(changeset, :watchers, new_watchers || [])
      end
    end

    update :reorder_watchers do
      accept [:watchers]
    end
  end

  policies do
    # For create, we bypass relationship-based policy check and use validation instead
    # because policies can't check relationships that don't exist yet
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

  sqlite do
    table "installations"
    repo Panic.Repo
  end
end
