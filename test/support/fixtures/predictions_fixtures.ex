defmodule Panic.PredictionsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Panic.Predictions` context.
  """

  import Panic.NetworksFixtures
  alias Panic.Predictions
  alias Panic.Predictions.Prediction

  @doc """
  Generate a (genesis) prediction.

  This is expecting a map of fake data; it won't be a genesis prediction, and
  as a "next" prediction there won't be any preceeding ones.

  """
  def prediction_fixture(attrs \\ %{}) do
    network = network_fixture()

    {:ok, prediction} =
      Map.merge(
        %{
          input: "some input",
          metadata: %{},
          model: "replicate:stability-ai/stable-diffusion",
          output: "some output",
          run_index: 0,
          network_id: network.id
        },
        attrs
      )
      |> Predictions.create_prediction_from_attrs()

    {:ok, prediction} = Predictions.update_prediction(prediction, %{genesis_id: prediction.id})

    prediction
  end
end
