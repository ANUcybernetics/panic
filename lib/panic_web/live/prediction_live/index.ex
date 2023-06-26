defmodule PanicWeb.PredictionLive.Index do
  use PanicWeb, :live_view

  alias Panic.Predictions
  alias Panic.Predictions.Prediction

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :predictions, Predictions.list_predictions())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Prediction")
    |> assign(:prediction, Predictions.get_prediction!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Prediction")
    |> assign(:prediction, %Prediction{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Predictions")
    |> assign(:prediction, nil)
  end

  @impl true
  def handle_info({PanicWeb.PredictionLive.FormComponent, {:saved, prediction}}, socket) do
    {:noreply, stream_insert(socket, :predictions, prediction)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    prediction = Predictions.get_prediction!(id)
    {:ok, _} = Predictions.delete_prediction(prediction)

    {:noreply, stream_delete(socket, :predictions, prediction)}
  end
end
