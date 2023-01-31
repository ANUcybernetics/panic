defmodule Panic.Predictions.Prediction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "predictions" do
    field :input, :string
    field :metadata, :map
    field :model, :string
    field :output, :string
    field :run_index, :integer
    belongs_to :network, Panic.Networks.Network
    belongs_to :genesis, Panic.Predictions.Prediction

    timestamps()
  end

  @doc false
  def changeset(prediction, attrs) do
    prediction
    |> cast(attrs, [:model, :input, :output, :metadata, :run_index])
    |> validate_required([:model, :input, :output, :metadata, :run_index])
  end
end
