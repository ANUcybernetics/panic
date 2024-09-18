defmodule PanicWeb.NetworkLive.Index do
  @moduledoc false
  use PanicWeb, :live_view

  alias Panic.Engine.Network

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Listing Networks
      <:actions>
        <.link patch={~p"/networks/new"}>
          <.button>New Network</.button>
        </.link>
      </:actions>
    </.header>

    <.table
      id="networks"
      rows={@streams.networks}
      row_click={fn {_id, network} -> JS.navigate(~p"/networks/#{network}") end}
    >
      <:col :let={{_id, network}} label="ID"><%= network.id %></:col>

      <:action :let={{_id, network}}>
        <div class="sr-only">
          <.link navigate={~p"/networks/#{network}"}>Show</.link>
        </div>

        <.link patch={~p"/networks/#{network}/edit"}>Edit</.link>
      </:action>

      <:action :let={{id, network}}>
        <.link
          phx-click={JS.push("delete", value: %{id: network.id}) |> hide("##{id}")}
          data-confirm="Are you sure?"
        >
          Delete
        </.link>
      </:action>
    </.table>

    <.modal :if={@live_action in [:new, :edit]} id="network-modal" show on_cancel={JS.patch(~p"/")}>
      <.live_component
        module={PanicWeb.NetworkLive.FormComponent}
        id={(@network && @network.id) || :new}
        current_user={@current_user}
        title={@page_title}
        action={@live_action}
        network={@network}
        patch={~p"/"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :networks, Ash.read!(Network))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Network")
    |> assign(:network, Ash.get!(Network, id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Network")
    |> assign(:network, nil)
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Networks")
    |> assign(:network, nil)
  end

  @impl true
  def handle_info({PanicWeb.NetworkLive.FormComponent, {:saved, network}}, socket) do
    {:noreply, stream_insert(socket, :networks, network)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    network = Ash.get!(Network, id)
    Ash.destroy!(network)

    {:noreply, stream_delete(socket, :networks, network)}
  end
end
