defmodule PanicWeb.NetworkLive.Show do
  use PanicWeb, :live_view

  alias Panic.Networks
  alias Panic.Predictions
  alias Panic.Predictions.Prediction
  alias Panic.Runs.StateMachine
  import PanicWeb.NetworkComponents

  # TODO pull these from params
  @num_grid_slots 18

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: empty_form())}
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
  def handle_event("reset", %{"network_id" => network_id}, socket) do
    StateMachine.transition(network_id, {:reset, nil})
    {:noreply, assign(socket, grid_slots: List.duplicate(nil, @num_grid_slots))}
  end

  @impl true
  def handle_event("lock", %{"network_id" => network_id}, socket) do
    StateMachine.transition(network_id, {:lock, 30})
    {:noreply, socket}
  end

  @impl true
  def handle_event("start-run", %{"prediction" => %{"input" => ""}}, socket),
    do: {:noreply, socket}

  @impl true
  def handle_event("start-run", %{"prediction" => %{"input" => input}}, socket) do
    Finitomata.transition(socket.assigns.network.id, {:genesis_input, input})
    {:noreply, assign(socket, form: empty_form())}
  end

  @impl true
  def handle_info({:new_prediction, prediction}, socket) do
    {:noreply, apply_action(socket, :new_prediction, prediction)}
  end

  @impl true
  def handle_info({:state_change, :running_genesis = state}, socket) do
    {:noreply,
     socket
     |> assign(state: state)
     |> apply_action(:reset_slots)}
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
    StateMachine.start_if_not_running(network)
    if connected?(socket), do: Networks.subscribe(network.id)

    socket
    |> assign(:network, network)
    |> assign(:models, network.models)
    |> apply_action(:reset_slots)
    |> assign(:missing_api_tokens, Panic.Accounts.missing_api_tokens(socket.assigns.current_user))
    |> assign(:state, StateMachine.get_current_state(network.id))
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
  end

  defp apply_action(socket, :reset_slots) do
    socket
    |> assign(:genesis, nil)
    |> assign(:grid_slots, List.duplicate(nil, @num_grid_slots))
  end

  defp empty_form() do
    %Predictions.Prediction{}
    |> Predictions.change_prediction()
    |> to_form()
  end
end
