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
        model_name: "some model_name",
        output: "some output",
        platform: :replicate
      })
      |> Panic.Models.create_run()

    run
  end
end
