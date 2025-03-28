defmodule PanicWeb.NetworkLive.Terminal do
  @moduledoc false
  use PanicWeb, :live_view

  alias PanicWeb.DisplayStreamer

  @impl true
  def render(assigns) do
    ~H"""
    <style>
      .terminal-container input {
        color: #d8b4fe;
        margin-top: 0;
      }
      .terminal-container input::placeholder {
        color: #f3e8ff;
      }
    </style>
    <div class="terminal-container p-8 text-purple-100 font-bold">
      <p class="min-h-12">
        <span>Current run:</span>
        <span :if={@genesis_invocation}><%= @genesis_invocation.input %></span>
      </p>
      <.live_component
        class="text-purple-100"
        module={PanicWeb.NetworkLive.TerminalComponent}
        network={@network}
        genesis_invocation={@genesis_invocation}
        current_user={@current_user}
        id={@network.id}
      />
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket, layout: {PanicWeb.Layouts, :display}}
  end

  @impl true
  def handle_params(%{"network_id" => network_id}, _, socket) do
    case Ash.get(Panic.Engine.Network, network_id, actor: socket.assigns.current_user) do
      {:ok, network} ->
        {:noreply,
         socket
         |> assign(:page_title, "Network #{network_id} terminal")
         |> DisplayStreamer.configure_invocation_stream(network, {:single, 0, 1})}

      {:error, _error} ->
        {:noreply, push_navigate(socket, to: ~p"/404")}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "invocation:" <> _} = message, socket) do
    DisplayStreamer.handle_invocation_message(message, socket)
  end

  @impl true
  def handle_info({PanicWeb.NetworkLive.TerminalComponent, {:genesis_invocation, genesis_invocation}}, socket) do
    {:noreply, assign(socket, :genesis_invocation, genesis_invocation)}
  end
end
