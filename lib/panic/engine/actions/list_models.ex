defmodule Panic.Engine.Actions.ListModels do
  @moduledoc "Describes every model in `Panic.Model.all/0`, for choosing a network's models."
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(_input, _opts, _context) do
    {:ok, Enum.map(Panic.Model.all(), &describe/1)}
  end

  defp describe(model) do
    model
    |> Map.take([:id, :name, :description, :homepage, :input_type, :output_type, :deprecated])
    |> Map.put(:platform, model.platform |> Module.split() |> List.last() |> String.downcase())
  end
end
