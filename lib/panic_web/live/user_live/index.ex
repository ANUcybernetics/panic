defmodule PanicWeb.UserLive.Index do
  @moduledoc false
  use PanicWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Listing Users
    </.header>

    <.table
      id="users"
      rows={@streams.users}
      row_click={fn {_id, user} -> JS.navigate(~p"/users/#{user}") end}
    >
      <:col :let={{_id, user}} label="ID">{user.id}</:col>

      <:col :let={{_id, user}} label="Email">{user.email}</:col>

      <:action :let={{_id, user}}>
        <div class="sr-only">
          <.link navigate={~p"/users/#{user}"}>Show</.link>
        </div>
      </:action>
    </.table>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> stream(:users, Panic.Accounts.list_users!(actor: socket.assigns.current_user))
     |> assign_new(:current_user, fn -> nil end)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, assign(socket, :page_title, "Listing Users")}
  end
end
