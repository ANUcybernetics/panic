defmodule PanicWeb.NetworkLive.Display do
  @moduledoc """
  Real-time display of network invocations.

  This module provides login-optional live views of the network's invocations as it runs.
  It displays the current state of invocations in real-time, allowing users to monitor
  the network's activity without requiring authentication.
  """
  use PanicWeb, :live_view

  import PanicWeb.PanicComponents

  alias PanicWeb.DisplayStreamer

  @impl true
  def render(assigns) do
    ~H"""
    <div :if={@live_action == :grid} class="px-4 pt-2 pb-4">
      <.live_component
        :if={@current_user}
        class="-mt-4 mb-4"
        module={PanicWeb.NetworkLive.TerminalComponent}
        network={@network}
        genesis_invocation={@genesis_invocation}
        current_user={@current_user}
        id={@network.id}
      />
      <p>
        <span class="text-purple-300/50">Last input:</span>
        <span :if={@genesis_invocation}><%= @genesis_invocation.input %></span>
      </p>
    </div>
    <.display invocations={@streams.invocations} display={@display} />
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, DisplayStreamer.configure_invocation_stream(socket, {:grid, 2, 3}), layout: {PanicWeb.Layouts, :display}}
  end

  # @impl true
  def handle_params(%{"redirect" => redirect}, _session, socket) do
    path =
      case String.graphemes(redirect) do
        ["s" | invocation_graphemes] -> ~p"/display/static/#{Enum.join(invocation_graphemes)}/"
        [network_id, offset, stride] -> ~p"/networks/#{network_id}/display/single/#{offset}/#{stride}/"
      end

    {:noreply, push_patch(socket, to: path)}
  end

  @impl true
  def handle_params(%{"network_id" => network_id} = params, _session, socket) do
    display =
      case {params, socket.assigns.live_action} do
        {%{"a" => a, "b" => b}, live_action} -> {live_action, String.to_integer(a), String.to_integer(b)}
        # the default grid for the link view
        {_, :links} -> {:grid, 2, 3}
      end

    case Ash.get(Panic.Engine.Network, network_id, actor: socket.assigns.current_user) do
      {:ok, network} ->
        {:noreply,
         socket
         |> assign(:page_title, "Panic display (network #{network_id})")
         |> assign(:display, display)
         |> DisplayStreamer.subscribe_to_invocation_stream(network)}

      {:error, _error} ->
        {:noreply, push_navigate(socket, to: ~p"/404")}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "invocation:" <> _} = message, socket) do
    DisplayStreamer.handle_invocation_message(message, socket)
  end
end
