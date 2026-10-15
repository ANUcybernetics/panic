defmodule PanicWeb.UserLive.Show do
  @moduledoc false
  use PanicWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      User email: {@user.email}
    </.header>

    <section>
      <div class="flex justify-between items-center mt-16">
        <h2 class="font-semibold">Networks</h2>
        <.link patch={~p"/users/#{@user}/new-network"} phx-click={JS.push_focus()}>
          <.button>Add network</.button>
        </.link>
      </div>

      <.table :if={@networks != []} id="network-list" rows={@networks}>
        <:col :let={network} label="Name">
          <.link href={~p"/networks/#{network}/"} phx-click={JS.push_focus()}>
            {network.name}
          </.link>
        </:col>
        <:col :let={network} label="Length">{length(network.models)}</:col>
        <:col :let={network} label="Description">{network.description}</:col>
        <:action :let={network}>
          <.link
            phx-click={JS.push("delete_network", value: %{id: network.id})}
            data-confirm="Are you sure you want to delete this network?"
            class="text-red-600 hover:text-red-900"
          >
            Delete
          </.link>
        </:action>
      </.table>
      <p :if={@networks == []} class="mt-8">User has no networks.</p>
    </section>

    <.back navigate={~p"/users"}>Back to users</.back>

    <.modal
      :if={@live_action == :new_network}
      id="new-network-modal"
      show
      on_cancel={JS.patch(~p"/users/#{@user}")}
    >
      <.live_component
        module={PanicWeb.NetworkLive.FormComponent}
        id={:new}
        title={@page_title}
        action={@live_action}
        current_user={@current_user}
        network={nil}
        navigate={~p"/users/#{@user}"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"user_id" => id}, _, socket) do
    case Panic.Accounts.get_user(id, actor: socket.assigns.current_user) do
      {:ok, user} ->
        networks = Panic.Engine.list_networks!(actor: socket.assigns.current_user)

        {:noreply,
         socket
         |> assign(:page_title, page_title(socket.assigns.live_action))
         |> assign(user: user, networks: networks)}

      {:error, _error} ->
        {:noreply, push_navigate(socket, to: ~p"/404")}
    end
  end

  @impl true
  def handle_info({PanicWeb.NetworkLive.FormComponent, {:saved, _network}}, socket) do
    # do nothing, because it re-triggers a handle_params, where we just read all the networks from the db
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_network", %{"id" => id}, socket) do
    network = Panic.Engine.get_network!(id, actor: socket.assigns.current_user)
    Panic.Engine.destroy_network!(network, actor: socket.assigns.current_user)

    networks = Panic.Engine.list_networks!(actor: socket.assigns.current_user)

    {:noreply, assign(socket, :networks, networks)}
  end

  defp page_title(:show), do: "Show User"
  defp page_title(:new_network), do: "Add Network"
end
