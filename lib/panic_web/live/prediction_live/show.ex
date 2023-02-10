defmodule PanicWeb.PredictionLive.Show do
  use PanicWeb, :live_view

  alias Panic.Predictions
  alias Panic.Networks

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"network_id" => network_id, "id" => id}, _, socket) do
    network = network_id |> String.to_integer() |> Networks.get_network!()

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:network, network)
     |> assign(:prediction, Predictions.get_prediction!(id))}
  end

  defp page_title(:show), do: "Show Prediction"
  defp page_title(:edit), do: "Edit Prediction"
end
