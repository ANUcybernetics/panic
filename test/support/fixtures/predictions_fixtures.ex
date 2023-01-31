defmodule Panic.PredictionsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Panic.Predictions` context.
  """

  @doc """
  Generate a prediction.
  """
  def prediction_fixture(attrs \\ %{}) do
    {:ok, prediction} =
      attrs
      |> Enum.into(%{
        input: "some input",
        metadata: %{},
        model: "some model",
        output: "some output",
        run_index: 42
      })
      |> Panic.Predictions.create_prediction()

    prediction
  end
end
