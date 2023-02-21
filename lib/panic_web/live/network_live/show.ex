defmodule PanicWeb.NetworkLive.Show do
  use PanicWeb, :live_view

  alias Panic.{Networks, Platforms}
  alias Panic.Networks.Network
  import PanicWeb.NetworkComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    network = Networks.get_network!(id)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:network, network)
     |> assign(:models, network.models)}
  end

  @impl true
  def handle_event("append-model", %{"model" => model}, socket) do
    {:ok, network} = Networks.append_model(socket.assigns.network, model)
    {:noreply, assign(socket, network: network, models: network.models)}
  end

  @impl true
  def handle_event("remove-last-model", _, socket) do
    {:ok, network} = Networks.remove_last_model(socket.assigns.network)
    {:noreply, assign(socket, network: network, models: network.models)}
  end

  defp page_title(:show), do: "Show Network"
  defp page_title(:edit), do: "Edit Network"
end
