defmodule PanicWeb.InstallationLive.Index do
  @moduledoc """
  LiveView for listing and managing installations.
  """
  use PanicWeb, :live_view

  alias Panic.Watcher.Installation

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Installations
      <:actions>
        <.link patch={~p"/installations/new"} phx-click={JS.push_focus()}>
          <.button>New Installation</.button>
        </.link>
      </:actions>
    </.header>

    <.table
      id="installations"
      rows={@streams.installations}
      row_click={fn {_id, installation} -> JS.navigate(~p"/installations/#{installation}") end}
    >
      <:col :let={{_id, installation}} label="Name">{installation.name}</:col>
      <:col :let={{_id, installation}} label="Network">
        {installation.network.name}
      </:col>
      <:col :let={{_id, installation}} label="Watchers">
        {length(installation.watchers)}
      </:col>
      <:action :let={{_id, installation}}>
        <div class="sr-only">
          <.link navigate={~p"/installations/#{installation}"}>Show</.link>
        </div>
        <.link patch={~p"/installations/#{installation}/edit"}>Edit</.link>
      </:action>
      <:action :let={{id, installation}}>
        <.link
          phx-click={JS.push("delete", value: %{id: installation.id}) |> hide("##{id}")}
          data-confirm="Are you sure?"
        >
          Delete
        </.link>
      </:action>
    </.table>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="installation-modal"
      show
      on_cancel={JS.patch(~p"/installations")}
    >
      <.live_component
        module={PanicWeb.InstallationLive.FormComponent}
        id={@installation.id || :new}
        title={@page_title}
        action={@live_action}
        installation={@installation}
        current_user={@current_user}
        networks={@networks}
        patch={~p"/installations"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> stream(:installations, list_installations(socket.assigns.current_user))
     |> assign(:networks, list_networks(socket.assigns.current_user))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Installation")
    |> assign(
      :installation,
      Ash.get!(Installation, id, actor: socket.assigns.current_user, load: [:network])
    )
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Installation")
    |> assign(:installation, %Installation{watchers: []})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Installations")
    |> assign(:installation, nil)
  end

  @impl true
  def handle_info({PanicWeb.InstallationLive.FormComponent, {:saved, installation}}, socket) do
    {:noreply, stream_insert(socket, :installations, installation)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    installation = Ash.get!(Installation, id, actor: socket.assigns.current_user)
    :ok = Ash.destroy(installation, actor: socket.assigns.current_user)

    {:noreply, stream_delete(socket, :installations, installation)}
  end

  defp list_installations(user) do
    Ash.read!(Installation, actor: user, load: [:network])
  end

  defp list_networks(user) do
    Ash.read!(Panic.Engine.Network, actor: user)
  end
end
