defmodule PanicWeb.NetworkLive.Terminal do
  @moduledoc false
  use PanicWeb, :live_view
  use PanicWeb.DisplayStreamer

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Terminal
    </.header>

    <.live_component
      module={PanicWeb.NetworkLive.TerminalComponent}
      network={@network}
      genesis_invocation={@genesis_invocation}
      current_user={@current_user}
      id={@network.id}
    />
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"network_id" => network_id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Network #{network_id} terminal")
     |> configure_display_stream(network_id, {:single, 1, 0})}
  end
end
