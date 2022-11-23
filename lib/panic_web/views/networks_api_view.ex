defmodule PanicWeb.NetworksAPIView do
  use PanicWeb, :view

  def render("show.json", %{network: network}) do
    network_to_json(network)
  end

  defp run_to_json(run) do
    run
    |> Map.take([:model, :input, :output, :cycle_index, :inserted_at, :id, :first_run_id])
  end

  defp network_to_json(network) do
    network
    |> Map.take([:inserted_at, :name, :models, :runs])
    |> Map.update!(:runs, fn runs -> Enum.map(runs, &run_to_json/1) end)
  end
end
