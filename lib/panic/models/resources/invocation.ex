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

    attribute :model, :module, allow_nil?: false
    attribute :input, :string, allow_nil?: false
    attribute :output, :string

    attribute :sequence_number, :integer do
      default 0
      constraints min: 0
      allow_nil? false
    end

    attribute :run_number, :integer do
      constraints min: 0
      allow_nil? false
    end

    attribute :metadata, :map, default: %{}, allow_nil?: false
    create_timestamp :inserted_at
  end

  actions do
    defaults [:read]

    create :create do
      accept [:model, :input, :run_number]
    end

    update :cancel do
      accept [:id]
    end
  end
end
