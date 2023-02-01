defmodule Panic.Networks.Network do
  use Ecto.Schema
  import Ecto.Changeset

  schema "networks" do
    field :description, :string
    field :models, {:array, :string}
    field :name, :string
    belongs_to :user, Panic.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(network, attrs) do
    network
    |> cast(attrs, [:models, :name, :description, :user_id])
    |> validate_required([:models, :name, :description, :user_id])
    |> foreign_key_constraint(:user)
  end
end
