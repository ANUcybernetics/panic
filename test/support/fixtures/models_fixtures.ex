defmodule Panic.ModelsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Panic.Models` context.
  """

  @doc """
  Generate a run.
  """
  def run_fixture(attrs \\ %{}) do
    {:ok, run} =
      attrs
      |> Enum.into(%{
        input: "some input",
        metadata: %{},
        model: "replicate:kuprel/min-dalle",
        output: "some output"
      })
      |> Panic.Models.create_run()

    run
  end

  @doc """
  Generate multiple runs (each one being the parent of subsequent ones)
  """
  def multi_run_fixture(attrs \\ %{}) do
    models = ["replicate:kuprel/min-dalle", "replicate:rmokady/clip_prefix_caption"]

    runs =
      models
      |> Enum.map(fn model ->
        attrs
        |> Enum.into(%{
          input: "some input",
          metadata: %{},
          model: model,
          output: "some output"
        })
        |> Panic.Models.create_run()
      end)
      |> Enum.map(fn {:ok, run} -> run end)

    runs
  end
end
