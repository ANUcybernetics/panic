defmodule Panic.Networks.Network do
  use Ecto.Schema
  import Ecto.Changeset

  schema "networks" do
    field :loop, :boolean, default: true
    field :models, {:array, :string}
    field :name, :string
    field :owner_id, :id

    timestamps()
  end

  @doc false
  def changeset(network, attrs) do
    network
    |> cast(attrs, [:name, :loop])
    |> validate_required([:name, :loop])
  end
end
