defmodule Panic.Accounts.APIToken do
  use Ecto.Schema
  import Ecto.Changeset

  schema "api_tokens" do
    field :name, :string
    field :token, :string
    belongs_to :user, Panic.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(api_token, attrs) do
    api_token
    |> cast(attrs, [:name, :token, :user_id])
    |> validate_required([:name, :token, :user_id])
    |> foreign_key_constraint(:user)
    |> unique_constraint([:user_id, :name])
  end
end
