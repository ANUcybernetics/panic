defmodule PanicWeb.NetworkLive.Show do
  use PanicWeb, :live_view

  alias Panic.Networks

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:network, Networks.get_network!(id))}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, push_patch(socket, to: Routes.network_show_path(socket, :show, socket.assigns.network))}
  end

  defp page_title(:show), do: "Show Network"
  defp page_title(:edit), do: "Edit Network"
end
