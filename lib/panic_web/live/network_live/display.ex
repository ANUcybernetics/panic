defmodule PanicWeb.NetworkLive.Display do
  @moduledoc false
  use PanicWeb, :live_view
  use PanicWeb.InvocationWatcher, watcher: {:single, 2, 0}

  @impl true
  def render(assigns) do
    ~H"""
    <div id="display" phx-update="stream">
      <p :for={{id, invocation} <- @streams.invocations} id={id}><%= invocation.model %> (<%= invocation.sequence_number%>): <%= invocation.output %></p>
    </div>
    """
  end

  @impl true
  def handle_params(%{"network_id" => network_id}, _session, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Panic display (network #{network_id})")
     |> subscribe_to_network(network_id, socket.assigns.current_user)}
  end
end
