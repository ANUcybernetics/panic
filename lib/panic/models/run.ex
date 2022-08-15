defmodule Panic.Models.Run do
  use Ecto.Schema
  import Ecto.Changeset
  alias Panic.Models

  schema "runs" do
    field :model, :string
    field :input, :string
    field :output, :string
    field :metadata, :map
    field :status, Ecto.Enum, values: [:created, :running, :succeeded, :failed], virtual: true
    belongs_to :parent, Models.Run
    belongs_to :first_run, Models.Run ## useful for grouping related runs
    belongs_to :network, Panic.Networks.Network

    timestamps()
  end

  @doc false
  def changeset(run, attrs) do
    run
    |> cast(attrs, [:model, :input, :output, :metadata, :parent_id, :first_run_id, :network_id])
    |> validate_required([:model, :input, :first_run_id, :network_id])
    |> validate_inclusion(:model, Models.list_models())
    |> foreign_key_constraint(:network_id)
    |> foreign_key_constraint(:parent_id)
    |> foreign_key_constraint(:first_run_id)
  end

  @doc false
  def first_run_starter(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:model, :network_id])
  end
end
