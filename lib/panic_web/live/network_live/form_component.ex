defmodule PanicWeb.NetworkLive.FormComponent do
  use PanicWeb, :live_component

  alias Panic.Networks

  @impl true
  def update(%{network: network} = assigns, socket) do
    changeset = Networks.change_network(network)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"network" => network_params}, socket) do
    changeset =
      socket.assigns.network
      |> Networks.change_network(network_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"network" => network_params}, socket) do
    save_network(socket, socket.assigns.action, network_params)
  end

  defp save_network(socket, :edit, network_params) do
    case Networks.update_network(socket.assigns.network, network_params) do
      {:ok, _network} ->
        {:noreply,
         socket
         |> put_flash(:info, "Network updated successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_network(socket, :new, network_params) do
    case Networks.create_network(network_params) do
      {:ok, _network} ->
        {:noreply,
         socket
         |> put_flash(:info, "Network created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
