defmodule Panic.Models.Run do
  use Ecto.Schema
  import Ecto.Changeset
  alias Panic.Models

  schema "runs" do
    field :model, :string
    field :input, :string
    field :output, :string
    field :metadata, :map
    belongs_to :parent, Models.Run
    belongs_to :network, Panic.Networks.Network

    timestamps()
  end

  @doc false
  def changeset(run, attrs) do
    run
    |> cast(attrs, [:model, :input, :output, :metadata, :parent_id, :network_id])
    |> validate_required([:model, :input, :network_id])
    |> validate_inclusion(:model, Models.list_models())
    |> foreign_key_constraint(:network_id)
    |> foreign_key_constraint(:parent_id)
  end
end
