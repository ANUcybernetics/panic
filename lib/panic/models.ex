defmodule Panic.Models do
  # this is a bit gross, because the :__info__ callback is meant to be used at runtime, so this
  # will cause weird errors in tests. Mostly useful for printing out the list of Models, which
  # can be manually kept in sync for use in `list/0` and `list/1`
  def list_model_modules do
    :code.all_loaded()
    |> Enum.filter(fn {mod, _} -> mod != :elixir_bootstrap end)
    |> Enum.filter(fn {mod, _} -> function_exported?(mod, :__info__, 1) end)
    |> Enum.filter(fn {mod, _} ->
      behaviours = Keyword.get(mod.__info__(:attributes), :behaviour, [])
      Panic.Model in behaviours
    end)
    |> Enum.map(fn {mod, _} -> mod end)
  end

  def list() do
    [
      Panic.Models.ClipPrefixCaption,
      Panic.Models.BLIP2,
      Panic.Models.CogPromptParrot,
      Panic.Models.GPT4Turbo,
      Panic.Models.SDXL,
      Panic.Models.GPT4,
      Panic.Models.LLaVA,
      Panic.Models.StableDiffusion,
      Panic.Models.ClipCaptionReward,
      Panic.Models.GPT4o,
      Panic.Models.LLaMa3Instruct8B
    ]
  end

  def list(filters) do
    list()
    |> Enum.filter(fn model ->
      filters
      |> Enum.map(fn {output, type} -> model.fetch!(output) == type end)
      |> Enum.all?()
    end)
  end
end
