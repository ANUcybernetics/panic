defmodule Panic.Models.GPT4 do
  @behaviour Panic.Model
  alias Panic.Platforms.OpenAI

  @impl true
  def info do %Panic.Models.ModelInfo{
      id: "gpt-4",
      path: "gpt-4",
      name: "GPT-4",
      description: "",
      input_type: :text,
      output_type: :text,
      platform: OpenAI
    }
  end

  @impl true
  def fetch!(field) do
    info() |> Map.fetch!(field)
  end

  @impl true
  def invoke(input), do: OpenAI.create(fetch!(:id), input)
end

defmodule Panic.Models.GPT4Turbo do
  @behaviour Panic.Model
  alias Panic.Platforms.OpenAI

  @impl true
  def info do
    %Panic.Models.ModelInfo{
      id: "gpt-4-turbo",
      path: "gpt-4-turbo",
      name: "GPT4 Turbo",
      description: "",
      input_type: :text,
      output_type: :text,
      platform: OpenAI
    }
  end

  @impl true
  def fetch!(field) do
    info() |> Map.fetch!(field)
  end

  @impl true
  def invoke(input), do: OpenAI.create(fetch!(:id), input)
end
