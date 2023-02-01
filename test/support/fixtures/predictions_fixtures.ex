defmodule Panic.PredictionsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Panic.Predictions` context.
  """

  import Panic.NetworksFixtures

  @doc """
  Generate a prediction.
  """
  def prediction_fixture(attrs \\ %{}) do
    network = network_fixture()

    {:ok, prediction} =
      Map.merge(
        %{
          input: "some input",
          metadata: %{},
          model: "some model",
          output: "some output",
          run_index: 42,
          network_id: network.id
        },
        attrs
      )
      |> Panic.Predictions.create_prediction()

    prediction
  end
end
