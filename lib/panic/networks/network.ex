defmodule Panic.Networks.Network do
  use Ecto.Schema
  import Ecto.Changeset

  schema "networks" do
    field :loop, :boolean, default: true
    field :models, {:array, :string}, default: []
    field :name, :string
    field :owner_id, :id

    has_many :runs, Panic.Models.Run

    timestamps()
  end

  @doc false
  def changeset(network, attrs) do
    network
    |> cast(attrs, [:name, :loop, :models])
    |> validate_required([:name, :loop, :models])
  end
end
