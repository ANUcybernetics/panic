defmodule Panic.Networks.Network do
  use Ecto.Schema
  import Ecto.Changeset

  schema "networks" do
    field :description, :string
    field :models, {:array, :string}, default: []
    field :name, :string
    belongs_to :user, Panic.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(network, attrs) do
    network
    |> cast(attrs, [:models, :name, :description, :user_id])
    |> validate_required([:name, :description, :user_id])
    |> validate_model_array()
    |> foreign_key_constraint(:user)
  end

  defp validate_model_array(changeset) do
    validate_change(changeset, :models, fn :models, model_array ->
      model_ids = Panic.Platforms.model_ids()

      for model_id <- model_array, model_id not in model_ids do
        model_id
      end
      |> case do
        [] -> []
        unsupported -> [{:models, "unsupported models: #{Enum.join(unsupported, " ")}"}]
      end
    end)
  end
end
