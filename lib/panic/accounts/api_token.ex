defmodule Panic.Accounts.APIToken do
  use Ecto.Schema
  import Ecto.Changeset

  schema "api_tokens" do
    field :name, :string
    field :token, :string
    field :user_id, :id

    timestamps()
  end

  @doc false
  def changeset(api_tokens, attrs) do
    api_tokens
    |> cast(attrs, [:name, :token])
    |> validate_required([:name, :token])
  end
end
