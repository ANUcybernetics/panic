defmodule PanicWeb.NetworkLive.Show do
  use PanicWeb, :live_view

  alias Panic.{Networks, Predictions}
  alias Panic.Predictions.Prediction
  import PanicWeb.NetworkComponents

  # TODO pull these from params
  @num_grid_slots 12

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    network = Networks.get_network!(id)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> apply_action(:new_network, network)}
  end

  @impl true
  def handle_event("append-model", %{"model" => model_id}, socket) do
    {:ok, network} = Networks.append_model(socket.assigns.network, model_id)
    {:noreply, assign(socket, network: network)}
  end

  @impl true
  def handle_event("remove-last-model", _, socket) do
    {:ok, network} = Networks.remove_last_model(socket.assigns.network)
    {:noreply, assign(socket, network: network, models: network.models)}
  end

  @impl true
  def handle_event("reset", %{"network_id" => network_id}, socket) do
    {:noreply, apply_action(socket, :reset_slots)}
  end

  @impl true
  def handle_event("lock", %{"network_id" => network_id}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:prediction_incoming, run_index}, socket) do
    {:noreply, assign(socket, :slot_incoming, Integer.mod(run_index, @num_grid_slots))}
  end

  @impl true
  def handle_info({:new_prediction, prediction}, socket) do
    {:noreply, apply_action(socket, :new_prediction, prediction)}
  end

  @impl true
  def handle_info({:state_change, :running_genesis = state}, socket) do
    {:noreply,
     socket
     |> apply_action(:reset_slots)
     |> assign(state: state)
     # this hack required because the :state_change event comes after
     # :prediction_incoming and clobbers it back to nil
     |> assign(:slot_incoming, 0)}
  end

  @impl true
  def handle_info({:state_change, state}, socket) do
    {:noreply, assign(socket, state: state)}
  end

  # pokemon
  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  defp page_title(:show), do: "Show Network"
  defp page_title(:edit), do: "Edit Network"

  defp apply_action(socket, :new_network, network) do
    if connected?(socket), do: Networks.subscribe(network.id)

    socket
    |> assign(:network, network)
    |> assign(:models, network.models)
    |> apply_action(:reset_slots)
    |> assign(:missing_api_tokens, Panic.Accounts.missing_api_tokens(socket.assigns.current_user))
  end

  defp apply_action(socket, :new_prediction, %Prediction{run_index: 0} = prediction) do
    socket
    |> assign(:genesis, prediction)
    |> update(:grid_slots, fn slots -> List.replace_at(slots, 0, prediction) end)
  end

  defp apply_action(socket, :new_prediction, %Prediction{run_index: idx} = prediction) do
    socket
    |> update(:grid_slots, fn slots ->
      List.replace_at(slots, Integer.mod(idx, @num_grid_slots), prediction)
    end)
    |> update(:genesis, fn genesis ->
      genesis || Predictions.get_prediction!(prediction.genesis_id)
    end)
  end

  defp apply_action(socket, :reset_slots) do
    socket
    |> assign(:genesis, nil)
    |> assign(:grid_slots, List.duplicate(nil, @num_grid_slots))
    |> assign(:slot_incoming, nil)
  end
end
