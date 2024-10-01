defmodule PanicWeb.NetworkLive.Display do
  @moduledoc false
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
    <.display invocations={@streams.invocations} />
    """
  end

  @impl true
  def handle_params(%{"network_id" => network_id, "a" => a, "b" => b}, _session, socket) do
    display = {socket.assigns.live_action, String.to_integer(a), String.to_integer(b)}

    {:noreply,
     socket
     |> assign(:page_title, "Panic display (network #{network_id})")
     |> configure_display_stream(network_id, display)}
  end
end
