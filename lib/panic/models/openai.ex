defmodule Panic.Models.GPT4 do
  @behaviour Panic.Model
  alias Panic.Platforms.OpenAI

  @info %Panic.Models.ModelInfo{
    id: "gpt-4",
    path: "gpt-4",
    name: "GPT-4",
    description: "",
    input_type: :text,
    output_type: :text,
    platform: OpenAI
  }

  @impl true
  def info, do: @info

  @impl true
  def info(field), do: Map.fetch!(@info, field)

  @impl true
  def invoke(input), do: OpenAI.create(@info.id, input)
end

defmodule Panic.Models.GPT4Turbo do
  @behaviour Panic.Model
  alias Panic.Platforms.OpenAI

  @info %Panic.Models.ModelInfo{
    id: "gpt-4-turbo",
    path: "gpt-4-turbo",
    name: "GPT4 Turbo",
    description: "",
    input_type: :text,
    output_type: :text,
    platform: OpenAI
  }

  @impl true
  def info, do: @info

  @impl true
  def info(field), do: Map.fetch!(@info, field)

  @impl true
  def invoke(input), do: OpenAI.create(@info.id, input)
end
