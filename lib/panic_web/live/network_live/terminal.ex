defmodule PanicWeb.NetworkLive.Terminal do
  @moduledoc false
  use PanicWeb, :live_view

  alias PanicWeb.InvocationWatcher
  alias PanicWeb.TerminalAuth

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
      @media (max-width: 640px) {
        .terminal-container {
          font-size: 0.875rem;
        }
        .terminal-container input {
          font-size: 1rem;
        }
      }
    </style>
    <div class="terminal-container p-4 sm:p-8 text-purple-100 font-bold">
      <p class="min-h-8 sm:min-h-12 text-sm sm:text-base">
        <span>Current run:</span>
        <span :if={@genesis_invocation} class="block sm:inline mt-1 sm:mt-0">
          {@genesis_invocation.input}
        </span>
      </p>
      <.live_component
        class="text-purple-100 mt-4 sm:mt-8"
        module={PanicWeb.NetworkLive.TerminalComponent}
        network={@network}
        genesis_invocation={@genesis_invocation}
        current_user={@network_user}
        lockout_seconds_remaining={@lockout_seconds_remaining}
        id={@network.id}
      />
    </div>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    # Authenticated users can bypass token requirement
    if socket.assigns[:current_user] do
      {:ok, socket, layout: {PanicWeb.Layouts, :display}}
    else
      # Unauthenticated users need a valid token
      case TerminalAuth.validate_token_in_socket(params, socket) do
        {:ok, socket} ->
          {:ok, socket, layout: {PanicWeb.Layouts, :display}}

        {:error, socket} ->
          # Socket already has redirect set by validate_token_in_socket
          {:ok, socket}
      end
    end
  end

  @impl true
  def handle_params(%{"network_id" => network_id}, _, socket) do
    # Load network with its user relationship (no actor needed for read)
    case Ash.get(Panic.Engine.Network, network_id, authorize?: false, load: [:user]) do
      {:ok, network} ->
        {:noreply,
         socket
         |> assign(:page_title, "Network #{network_id} terminal")
         |> assign(:network_user, network.user)
         |> InvocationWatcher.configure_invocation_stream(network, {:single, 0, 1, false})}

      {:error, _error} ->
        {:noreply, push_navigate(socket, to: ~p"/404")}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "invocation:" <> _} = message, socket) do
    InvocationWatcher.handle_invocation_message(message, socket)
  end

  @impl true
  def handle_info({PanicWeb.NetworkLive.TerminalComponent, {:genesis_invocation, genesis_invocation}}, socket) do
    {:noreply, assign(socket, :genesis_invocation, genesis_invocation)}
  end
end
