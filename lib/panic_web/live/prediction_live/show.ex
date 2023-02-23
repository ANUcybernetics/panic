defmodule PanicWeb.PredictionLive.Show do
  use PanicWeb, :live_view

  alias Panic.Predictions
  import PanicWeb.NetworkComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"network_id" => _network_id, "prediction_id" => prediction_id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Show Prediction")
     |> assign(:prediction, Predictions.get_prediction!(prediction_id))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.prediction_card prediction={@prediction} />
    """
  end
end
