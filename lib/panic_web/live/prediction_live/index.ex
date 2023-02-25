defmodule PanicWeb.PredictionLive.Index do
  use PanicWeb, :live_view

  alias Panic.Predictions
  alias Panic.Networks
  import PanicWeb.NetworkComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"network_id" => network_id}, _, socket) do
    network = Networks.get_network!(network_id)
    # if connected?(socket), do: Networks.subscribe(network.id)

    {:noreply, apply_action(socket, socket.assigns.live_action, network)}
  end

  defp list_predictions(%Networks.Network{} = network, limit \\ 100) do
    Predictions.list_predictions(network, limit)
  end

  defp apply_action(socket, :index, network) do
    socket
    |> assign(:page_title, "Listing Predictions")
    |> assign(:network, network)
    |> assign(:predictions, list_predictions(network))
  end

  defp group_by_run(predictions) do
    predictions
    |> Enum.chunk_by(fn p -> p.genesis_id end)
    |> Enum.map(fn [genesis | _] = preds -> {genesis, preds} end)
  end
end
