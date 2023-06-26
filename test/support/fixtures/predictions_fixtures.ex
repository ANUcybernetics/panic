defmodule Panic.PredictionsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Panic.Predictions` context.
  """

  alias Panic.Predictions

  @doc """
  Generate a (genesis) prediction fixture.
  """
  def genesis_prediction_fixture(%Panic.Networks.Network{} = network) do
    changeset = Predictions.Prediction.genesis_changeset("some input", network)

    {:ok, prediction} =
      changeset.params
      |> Map.put("output", "some output")
      |> Predictions.create_prediction()

    prediction
  end

  @doc """
  Generate a prediction fixture from attrs.

  This doesn't check if it's a valid genesis/next prediction, and expects you to
  do all the leg-work to pass in appropriate `attrs` for your use-case.

  """
  def prediction_fixture(attrs \\ %{}) do
    {:ok, prediction} = Predictions.create_prediction(attrs)
    prediction
  end

  @doc """
  Generate a prediction.
  """
  def prediction_fixture(attrs \\ %{}) do
    {:ok, prediction} =
      attrs
      |> Enum.into(%{
        input: "some input",
        output: "some output",
        metadata: %{},
        model: "some model",
        run_index: 42
      })
      |> Panic.Predictions.create_prediction()

    prediction
  end
end
