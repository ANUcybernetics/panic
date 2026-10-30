defmodule PanicWeb.NetworkLive.Index do
  @moduledoc """
  The signed-in user's networks: the home page once you're signed in.
  """
  use PanicWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        Networks
        <:actions>
          <.button patch={~p"/networks/new"} variant="primary">
            <.icon name="hero-plus" /> New network
          </.button>
        </:actions>
      </.header>

      <.table
        :if={@networks != []}
        id="networks"
        rows={@networks}
        row_id={&"network-#{&1.id}"}
        row_click={&JS.navigate(~p"/networks/#{&1}")}
      >
        <:col :let={network} label="Name">
          <.link navigate={~p"/networks/#{network}"} class="font-semibold">{network.name}</.link>
        </:col>
        <:col :let={network} label="Models">{length(network.models)}</:col>
        <:col :let={network} label="Description" class="hidden sm:table-cell">
          <span class="line-clamp-2">{network.description}</span>
        </:col>
        <:action :let={network}>
          <.button
            phx-click={JS.push("delete", value: %{id: network.id})}
            data-confirm="Are you sure you want to delete this network?"
            variant="error"
            size="sm"
          >
            Delete
          </.button>
        </:action>
      </.table>
      <p :if={@networks == []} class="text-base-content/70">
        No networks yet. Make one to start a run.
      </p>

      <.modal
        :if={@live_action == :new}
        id="new-network-modal"
        show
        on_cancel={JS.patch(~p"/networks")}
      >
        <.live_component
          module={PanicWeb.NetworkLive.FormComponent}
          id={:new}
          current_user={@current_user}
          title={@page_title}
          action={@live_action}
          network={nil}
          navigate={nil}
        />
      </.modal>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_networks(socket)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, assign(socket, :page_title, page_title(socket.assigns.live_action))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    network = Panic.Engine.get_network!(id, actor: actor)
    Panic.Engine.destroy_network!(network, actor: actor)

    {:noreply, assign_networks(socket)}
  end

  defp assign_networks(socket) do
    assign(socket, :networks, Panic.Engine.list_networks!(actor: socket.assigns.current_user))
  end

  defp page_title(:index), do: "Networks"
  defp page_title(:new), do: "New network"
end
