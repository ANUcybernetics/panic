defmodule Panic.Predictions.Prediction do
  use Ecto.Schema
  import Ecto.Changeset
  alias Panic.Predictions.Prediction
  alias Panic.Networks.Network

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
    |> cast(attrs, [:model, :input, :output, :metadata, :run_index, :network_id, :genesis_id])
    |> validate_required([
      :model,
      :input,
      :output,
      :metadata,
      :run_index,
      :network_id
    ])
    |> foreign_key_constraint(:network)
    |> foreign_key_constraint(:genesis)
  end

  @doc """
  Create a genesis changeset

  Only network and input are required, all the other params can be derived.
  """
  def genesis_changeset(input, %Network{} = network) when is_binary(input) do
    attrs = %{
      input: input,
      model: List.first(network.models),
      run_index: 0,
      metadata: %{},
      network_id: network.id
    }

    changeset(%Prediction{}, attrs)
  end

  @doc """
  Create a "next" changeset

  Only the previous prediction is required, all the other params can be derived.
  """
  def next_changeset(%Prediction{} = previous_prediction) do
    run_index = previous_prediction.run_index + 1
    network = previous_prediction.network
    model_id = Enum.at(network.models, Integer.mod(run_index, Enum.count(network.models)))
    input = previous_prediction.output

    attrs = %{
      input: input,
      model: model_id,
      run_index: run_index,
      metadata: %{},
      network_id: network.id,
      genesis_id: previous_prediction.genesis_id
    }

    changeset(%Prediction{}, attrs)
  end

  def add_output(%Ecto.Changeset{params: params}, output) when is_binary(output) do
    %Prediction{}
    |> changeset(Map.put(params, "output", output))
  end
end
