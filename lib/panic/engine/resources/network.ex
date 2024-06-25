defmodule Panic.Engine.Network do
  @moduledoc """
  A Network represents a specific network (i.e. cyclic graph) of models.
  """
  use Ash.Resource,
    domain: Panic.Engine,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "networks"
    repo Panic.Repo
  end

  attributes do
    integer_primary_key :id

    # attribute :owner
    attribute :name, :string do
      allow_nil? false
    end

    attribute :description, :string

    attribute :models, {:array, :module} do
      default []
      allow_nil? false
      # TODO validate that the module conforms to the Model behaviour
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
    defaults [:read, :destroy]

    create :create do
      accept [:name, :description, :models]

      # change fn changeset, _ ->
      #   changeset
      #   |> set_attribute(:slug, Panic.Slug.generate(changeset.data.name))
      #   |> set_attribute(:state, :stopped)
      # end
    end

    read :by_id do
      argument :id, :integer
      get? true
      filter expr(id == ^arg(:id))
    end

    update :append_model do
      # describe("Append a model to the end of the list of models")
      argument :model, Ash.Type.Module, allow_nil?: false

      change fn changeset, _ ->
        set_attribute(
          changeset,
          :models,
          List.insert_at(changeset.data.models, -1, :model)
        )
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
      change set_attribute(:state, arg(:state))
    end
  end
end
