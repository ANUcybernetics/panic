defmodule Panic.Predictions.Prediction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "predictions" do
    field :input, :string
    field :metadata, :map
    field :model, :string
    field :output, :string
    field :run_index, :integer
    field :network_id, :id
    field :genesis_id, :id

    timestamps()
  end

  @doc false
  def changeset(prediction, attrs) do
    prediction
    |> cast(attrs, [:model, :input, :output, :metadata, :run_index])
    |> validate_required([:model, :input, :output, :metadata, :run_index])
  end
end
