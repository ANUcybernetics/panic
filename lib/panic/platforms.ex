defmodule Panic.Platforms do
  @moduledoc """
  The Platforms context.

  The platforms & model configuration isn't in the DB, so this context is a bit
  different from the standard Phoenix one.
  """

  def list_platforms do
    [Panic.Platforms.OpenAI, Panic.Platforms.Replicate]
  end

  def all_model_info do
    for platform <- list_platforms(), reduce: %{} do
      acc -> Map.merge(acc, platform.all_model_info())
    end
  end

  def list_models do
    Map.keys(all_model_info())
  end

  def model_info(model) do
    all_model_info() |> Map.get(model)
  end

  def model_input_type(model) do
    model |> model_info() |> Map.get(:input)
  end

  def model_output_type(model) do
    model |> model_info() |> Map.get(:output)
  end

  def api_call(model, input, user) do
    [platform, model_name] = String.split(model, ":")

    case platform do
      "replicate" -> Panic.Platforms.Replicate.create(model_name, input, user)
      "openai" -> Panic.Platforms.OpenAI.create(model_name, input, user)
    end
  end
end
