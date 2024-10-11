defmodule PanicWeb.NetworkLive.Display do
  @moduledoc """
  Real-time display of network invocations.

  This module provides login-optional live views of the network's invocations as it runs.
  It displays the current state of invocations in real-time, allowing users to monitor
  the network's activity without requiring authentication.
  """
  use PanicWeb, :live_view
  use PanicWeb.DisplayStreamer

  import PanicWeb.PanicComponents

  @impl true
  def render(assigns) do
    ~H"""
    <p :if={@live_action == :grid} class="px-4 pt-2 pb-4">
      <span class="text-purple-300/50">Last input:</span>
      <span :if={@genesis_invocation}><%= @genesis_invocation.input %></span>
    </p>
    <.display invocations={@streams.invocations} display={@display} />
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket, layout: {PanicWeb.Layouts, :display}}
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

    {:noreply,
     socket
     |> assign(:page_title, "Panic display (network #{network_id})")
     |> configure_display_stream(network_id, display)}
  end
end
