defmodule Panic.Models.Invocation do
  @moduledoc """
  A resource representing a specific "inference" run for a single model

  The resource includes both the input (prompt) an the output (prediction)
  along with some other metadata.
  """
  use Ash.Resource,
    domain: Panic.Models,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "models"
    repo Panic.Repo
  end

  attributes do
    integer_primary_key :id

    attribute :input, :string, allow_nil?: false
    attribute :model, :module
    attribute :output, :string

    attribute :sequence_number, :integer do
      default 0
      constraints min: 0
      allow_nil? false
    end

    attribute :run_number, :integer do
      constraints min: 0
    end

    attribute :metadata, :map, default: %{}, allow_nil?: false
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read]

    read :by_id do
      argument :id, :integer
      get? true
      filter expr(id == ^arg(:id))
    end

    create :create_first do
      accept [:input]
      argument :network, :map, allow_nil?: false
      change Panic.Changes.Invoke
    end

    create :create_next do
      argument :parent_id, :integer, allow_nil?: false
    end

    update :finalise do
      accept [:output]
      change set_attribute(:output, arg(:output))
    end
  end

  relationships do
    belongs_to :network, Panic.Topology.Network, allow_nil?: false
  end
end
