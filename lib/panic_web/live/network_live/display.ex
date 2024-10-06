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
    <p class="mb-8">
      Display mode: <%= with {type, _, _} <- @display, do: type %> (<%= Enum.count(
        @streams.invocations
      ) %> invocations)
    </p>
    <.display invocations={@streams.invocations} display={@display} />

    <div :if={@live_action == :links} id="display-links">
      <ul class="flex flex-col space-y-8">
        <%= for i <- 0..7 do %>
          <.link navigate={~p"/networks/#{@network.id}/display/single/#{i}/8/"}>
            <li>Screen <%= i + 1 %></li>
          </.link>
        <% end %>
      </ul>
    </div>
    """
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
