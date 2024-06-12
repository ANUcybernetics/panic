defmodule Panic.StreamGenerators do
  @moduledoc """
  StreamData generators for Panic

  - model info
  - model module

  """
  use ExUnitProperties

  def model_info() do
    gen all(
          id <- binary(),
          platform <- member_of([Panic.Platforms.OpenAI, Panic.Platforms.Replicate]),
          path <- binary(),
          name <- binary(),
          description <- binary(),
          input_type <- member_of([:text, :image, :audio]),
          output_type <- member_of([:text, :image, :audio])
        ) do
      %Panic.Models.ModelInfo{
        id: id,
        platform: platform,
        path: path,
        name: name,
        description: description,
        input_type: input_type,
        output_type: output_type
      }
    end
  end

  def model_module do
    gen all(
          model_name <- atom(:alias),
          model_info <- model_info(),
          invocation_result <- member_of([{:ok, "great"}, {:error, "whoops"}])
        ) do
      contents =
        quote do
          @behaviour Panic.Model

          @impl true
          def info do
            unquote(Macro.escape(model_info))
          end

          @impl true
          def fetch!(field) do
            info() |> Map.fetch!(field)
          end

          @impl true
          def invoke(input), do: unquote(invocation_result)
        end

      {:module, module, _, _} = Module.create(model_name, contents, Macro.Env.location(__ENV__))

      module
    end
  end
end
