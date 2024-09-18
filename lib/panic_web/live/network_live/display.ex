defmodule PanicWeb.NetworkLive.Display do
  @moduledoc false
  use PanicWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    Display.
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
     |> assign(:page_title, "Network #{id} display")
     |> assign(:network, Ash.get!(Panic.Engine.Network, id))}
  end
end
