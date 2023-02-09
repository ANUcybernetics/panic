defmodule PanicWeb.NetworkLive.Index do
  use PanicWeb, :live_view

  alias Panic.Networks
  alias Panic.Networks.Network

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :networks, list_networks(socket.assigns.current_user))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Network")
    |> assign(:network, Networks.get_network!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Network")
    |> assign(:network, %Network{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Networks")
    |> assign(:network, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    network = Networks.get_network!(id)
    {:ok, _} = Networks.delete_network(network)

    {:noreply, assign(socket, :networks, list_networks(socket.assigns.current_user))}
  end

  defp list_networks(%Panic.Accounts.User{} = user) do
    Accounts.list_networks(user)
  end
end
