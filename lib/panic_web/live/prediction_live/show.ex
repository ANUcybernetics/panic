defmodule PanicWeb.PredictionLive.Show do
  use PanicWeb, :live_view

  alias Panic.Predictions
  alias Panic.Networks

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"network_id" => network_id, "prediction_id" => prediction_id}, _, socket) do
    network = Networks.get_network!(network_id)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:network, network)
     |> assign(:prediction, Predictions.get_prediction!(prediction_id))}
  end

  defp page_title(:show), do: "Show Prediction"
end
