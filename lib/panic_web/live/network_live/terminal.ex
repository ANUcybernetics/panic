defmodule PanicWeb.NetworkLive.Terminal do
  use PanicWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <%= @network.name %> Terminal
    </.header>

    <.live_component
      module={PanicWeb.NetworkLive.TerminalComponent}
      network={@network}
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
  def handle_params(%{"network_id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Network #{id} terminal")
     |> assign(:network, Ash.get!(Panic.Engine.Network, id, actor: socket.assigns.current_user))}
  end
end
