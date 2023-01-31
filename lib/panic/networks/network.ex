defmodule Panic.Networks.Network do
  use Ecto.Schema
  import Ecto.Changeset

  schema "networks" do
    field :description, :string
    field :models, {:array, :string}
    field :name, :string
    field :user_id, :id

    timestamps()
  end

  @doc false
  def changeset(network, attrs) do
    network
    |> cast(attrs, [:models, :name, :description])
    |> validate_required([:models, :name, :description])
  end
end
