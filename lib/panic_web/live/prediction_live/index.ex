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
  def handle_params(%{"network_id" => network_id} = params, _, socket) do
    network = Networks.get_network!(network_id)

    {:noreply,
     apply_action(assign(socket, :network, network), socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _) do
    socket
    |> assign(:page_title, "Listing Predictions")
    |> assign(:predictions, list_predictions(socket.assigns.network))
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    prediction = Predictions.get_prediction!(id)
    {:ok, _} = Predictions.delete_prediction(prediction)

    {:noreply, assign(socket, :predictions, list_predictions(socket.assigns.network))}
  end

  defp list_predictions(%Networks.Network{} = network) do
    Predictions.list_predictions(network, 100)
  end
end
