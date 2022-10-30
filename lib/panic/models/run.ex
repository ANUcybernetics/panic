defmodule Panic.Models.Run do
  use Ecto.Schema
  import Ecto.Changeset
  alias Panic.Models

  schema "runs" do
    field :model, :string
    field :input, :string
    field :output, :string
    field :metadata, :map

    field :status, Ecto.Enum,
      values: [:created, :running, :succeeded, :failed],
      virtual: true,
      default: :created

    ## note: the index can be calculated from the chain of parentage, so this
    ## isn't strictly necessary, but it's nice to have in the DB anyway
    field :cycle_index, :integer, default: 0
    belongs_to :parent, Models.Run
    ## useful for grouping related runs
    belongs_to :first_run, Models.Run
    belongs_to :network, Panic.Networks.Network

    timestamps()
  end

  @doc false
  def changeset(run, attrs) do
    run
    |> cast(attrs, [:model, :input, :output, :metadata, :cycle_index, :parent_id, :first_run_id, :network_id])
    |> validate_required([:model, :input, :network_id])
    |> validate_inclusion(:model, Models.list_models())
    |> validate_number(:cycle_index, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:network_id)
    |> foreign_key_constraint(:parent_id)
    |> foreign_key_constraint(:first_run_id)
  end
end
