defmodule Panic.Models do
  def list do
    :code.all_loaded()
    |> Enum.filter(fn {mod, _} -> implements_model(mod) end)
    |> Enum.map(fn {mod, _} -> mod end)
  end

  def list(platform) do
    list()
    |> Enum.filter(fn model -> model.fetch!(:platform) == platform end)
  end

  defp implements_model(module) do
    if function_exported?(module, :__info__, 1) do
      behaviours = Keyword.get(module.__info__(:attributes), :behaviour, [])
      Panic.Model in behaviours
    else
      false
    end
  end
end
