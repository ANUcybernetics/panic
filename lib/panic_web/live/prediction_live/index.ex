defmodule PanicWeb.PredictionLive.Index do
  use PanicWeb, :live_view

  alias Panic.Predictions
  alias Panic.Predictions.Prediction
  alias Panic.Networks
  alias Panic.Networks.Network
  import PanicWeb.NetworkComponents

  @impl true
  def mount(_params, _session, socket) do
    if has_all_required_api_tokens?(socket.assigns.current_user) do
      {:ok, socket}
    else
      {:ok,
       socket
       |> push_navigate(to: ~p"/api_tokens/new")
       |> put_flash(
         :info,
         ~s("OpenAI" and "Replicate" API tokens are required to run Panic!, please add them now)
       )}
    end
  end

  @impl true
  def handle_params(%{"network_id" => network_id} = params, _, socket) do
    network = Networks.get_network!(network_id)

    {:noreply,
     apply_action(assign(socket, :network, network), socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Prediction")
    |> assign(:prediction, %Prediction{})
    |> assign(:predictions, list_predictions(socket.assigns.network))
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

  defp list_predictions(%Network{} = network) do
    Predictions.list_predictions(network, 100)
  end

  defp has_all_required_api_tokens?(user) do
    token_names =
      user
      |> Panic.Repo.preload([:api_tokens])
      |> Map.get(:api_tokens)
      |> Enum.map(& &1.name)

    "OpenAI" in token_names and "Replicate" in token_names
  end
end
