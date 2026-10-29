defmodule PanicWeb.NetworkLive.Terminal do
  @moduledoc false
  use PanicWeb, :live_view

  alias PanicWeb.NetworkLive.NetworkHelpers
  alias PanicWeb.TerminalAuth
  alias PanicWeb.WatcherSubscriber

  @impl true
  def render(assigns) do
    ~H"""
    <style>
      /* the display layout's 200% suits a big screen, but this page is also
         what a phone shows after scanning the QR code */
      :root {
        font-size: clamp(100%, 2.5vw, 200%);
      }
    </style>
    <div class="terminal-container mx-auto max-w-5xl p-4 sm:p-8">
      <p class="min-h-12 break-words text-primary-content">
        <span class="text-base-content/60">Current run:</span>
        <span :if={@genesis_invocation}>{@genesis_invocation.input}</span>
      </p>
      <.live_component
        class="mt-4 sm:mt-8"
        module={PanicWeb.NetworkLive.TerminalComponent}
        network={@network}
        genesis_invocation={@genesis_invocation}
        current_user={@network_user}
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
    case Panic.Engine.get_network(network_id, authorize?: false, load: [:user]) do
      {:ok, network} ->
        # Check if network has missing models - redirect to network show if broken
        case NetworkHelpers.check_network_models(network.models) do
          {:ok, _models} ->
            {:noreply,
             socket
             |> assign(:page_title, "Network #{network_id} terminal")
             |> assign(:network_user, network.user)
             |> WatcherSubscriber.configure_invocation_stream(network, {:single, 0, 1, false})}

          {:error, missing_ids} ->
            {:noreply, NetworkHelpers.handle_broken_network(socket, network, missing_ids)}
        end

      {:error, _error} ->
        {:noreply, push_navigate(socket, to: ~p"/404")}
    end
  end

  @impl true
  def handle_info({PanicWeb.NetworkLive.TerminalComponent, {:genesis_invocation, genesis_invocation}}, socket) do
    {:noreply, assign(socket, :genesis_invocation, genesis_invocation)}
  end
end
