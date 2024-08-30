defmodule PanicWeb.UserLive.Show do
  use PanicWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      User <%= @user.id %>
      <:subtitle>This is a user record from your database.</:subtitle>

      <:actions>
        <.link patch={~p"/users/#{@user}/edit"} phx-click={JS.push_focus()}>
          <.button>Edit user</.button>
        </.link>
      </:actions>
    </.header>

    <.list>
      <:item title="ID"><%= @user.id %></:item>

      <:item title="Email"><%= @user.email %></:item>
    </.list>

    <.back navigate={~p"/users"}>Back to users</.back>

    <.modal :if={@live_action == :edit} id="user-modal" show on_cancel={JS.patch(~p"/users/#{@user}")}>
      <.live_component
        module={PanicWeb.UserLive.FormComponent}
        id={@user.id}
        title={@page_title}
        action={@live_action}
        current_user={@current_user}
        user={@user}
        patch={~p"/users/#{@user}"}
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
    user =
      Panic.Accounts.User
      |> Ash.get!(id, actor: socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:user, user)}
  end

  @impl true
  def handle_info({PanicWeb.UserLive.FormComponent, {:saved, user}}, socket) do
    {:noreply, assign(socket, user: user)}
  end

  defp page_title(:show), do: "Show User"
  defp page_title(:edit), do: "Edit User"
end
