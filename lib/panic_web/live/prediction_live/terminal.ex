defmodule PanicWeb.PredictionLive.Terminal do
  @moduledoc """
  The main Panic "input terminal".

  The form her is so simple (just a text input) that it doesn't do the usual
  changeset thing; it just grabs the input string and dispatches it straight to
  `Predictions.create_prediction_async/3`.

  """
  use PanicWeb, :live_view
  alias Panic.{Accounts, Networks}
  alias Panic.Runs.StateMachine

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      id="terminal-input"
      module={PanicWeb.PredictionLive.GensisInputComponent}
      panic_button?={@state in [:ready, :interruptable]}
    />
    <div class="fixed bottom-8 left-8 text-lg"><%= state_label(@state) %></div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    missing_tokens = Accounts.missing_api_tokens(socket.assigns.current_user)

    if Enum.empty?(missing_tokens) do
      {:ok, socket}
    else
      {:ok, apply_action(socket, :tokens_missing, missing_tokens)}
    end
  end

  @impl true
  def handle_params(%{"network_id" => network_id}, _, socket) do
    network = Networks.get_network!(network_id)
    {:noreply, apply_action(socket, :new_network, network)}
  end

  @impl true
  def handle_info({:prediction_incoming, run_index}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:genesis_input, _input} = payload, socket) do
    Finitomata.transition(socket.assigns.network.id, payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:state_change, state}, socket) do
    {:noreply, assign(socket, state: state)}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  defp apply_action(socket, :tokens_missing, missing_tokens) do
    socket
    |> put_flash(:info, "#{Enum.join(missing_tokens, "/")} API tokens are required to run Panic!")
  end

  defp apply_action(socket, :new_network, network) do
    StateMachine.start_if_not_running(network)
    if connected?(socket), do: Networks.subscribe(network.id)

    socket
    |> assign(:network, network)
    |> assign(:state, StateMachine.get_current_state(network.id))
  end

  defp state_label(state) when state in [:running_genesis, :uninterruptable], do: "please wait"
  defp state_label(:interruptable), do: "ready"
  defp state_label(state), do: Atom.to_string(state)
end
