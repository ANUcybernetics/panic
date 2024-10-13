defmodule PanicWeb.NetworkLive.Terminal do
  @moduledoc false
  use PanicWeb, :live_view

  alias PanicWeb.DisplayStreamer

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-dvh grid place-items-center">
      <div class="lg:w-1/2">
        <.live_component
          class="mb-16"
          module={PanicWeb.NetworkLive.TerminalComponent}
          network={@network}
          genesis_invocation={@genesis_invocation}
          current_user={@current_user}
          id={@network.id}
        />

        <p>
          <span class="max-w-full text-purple-300/50">Last input:</span>
          <span :if={@genesis_invocation}><%= @genesis_invocation.input %></span>
        </p>
      </div>
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
