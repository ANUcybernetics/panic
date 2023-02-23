defmodule PanicWeb.NetworkLive.Show do
  use PanicWeb, :live_view

  alias Panic.Networks
  alias Panic.Predictions.Prediction
  alias Panic.Runs.StateMachine
  import PanicWeb.NetworkComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    network = Networks.get_network!(id)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> apply_action(:new_network, network)}
  end

  @impl true
  def handle_event("append-model", %{"model" => model}, socket) do
    {:ok, network} = Networks.append_model(socket.assigns.network, model)
    {:noreply, assign(socket, network: network, models: network.models)}
  end

  @impl true
  def handle_event("remove-last-model", _, socket) do
    {:ok, network} = Networks.remove_last_model(socket.assigns.network)
    {:noreply, assign(socket, network: network, models: network.models)}
  end

  @impl true
  def handle_info({:new_prediction, %Prediction{run_index: 0} = prediction}, socket) do
    {:noreply, assign(socket, genesis: prediction)}
  end

  # pokemon
  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  defp page_title(:show), do: "Show Network"
  defp page_title(:edit), do: "Edit Network"

  defp apply_action(socket, :new_network, network) do
    StateMachine.start_if_not_running(network)
    if connected?(socket), do: Networks.subscribe(network.id)

    socket
    |> assign(:network, network)
    |> assign(:models, network.models)
    |> assign(:missing_api_tokens, Panic.Accounts.missing_api_tokens(socket.assigns.current_user))
    |> assign(:current_state, StateMachine.current_state(network.id))
  end
end
