defmodule PanicWeb.AdminUsersLive do
  @moduledoc """
  A live view to admin users on the platform (edit/suspend/delete).
  """
  use PanicWeb, :live_view
  alias Panic.{Accounts, Accounts.User}
  alias PanicWeb.UserAuth
  import PanicWeb.AdminLayoutComponent

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(params, url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params, url)}
  end

  def apply_action(socket, :index, _params, url) do
    socket
    |> assign(%{
      page_title: "Admin users",
      changeset: nil,
      url: url
    })
  end

  def apply_action(socket, :edit, %{"user_id" => user_id}, url) do
    user = Accounts.get_user!(user_id)
    socket = assign_new(socket, :url, fn -> url end)

    assign(socket, %{
      page_title: "Editing #{PanicWeb.Helpers.user_name(user)}",
      changeset: Accounts.change_user_as_admin(user)
    })
  end

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={:admin_users} current_user={@current_user}>
      <.page_header title="Users" />

      <.live_component
        module={DataTable}
        id="admin-users-table"
        url={@url}
        ecto_query={User}
        default_order={
          %{
            order_by: [:id, :inserted_at],
            order_directions: [:asc, :asc]
          }
        }
      >
        <:col field={:id} sortable type={:integer} class="w-24" /><:col
          field={:name}
          sortable
          filterable={[:=~]}
        /><:col field={:email} sortable filterable={[:=~]} /><:col
          field={:is_suspended}
          type={:boolean}
          filterable={[:==]}
          renderer={:checkbox}
        />
        <:col :let={user} label="Actions">
          <.user_actions socket={@socket} user={user} />
        </:col>
      </.live_component>
    </.admin_layout>

    <%= if @changeset do %>
      <.modal title={@changeset.data.name}>
        <div class="text-sm">
          <.form :let={f} for={@changeset} phx-submit="update_user">
            <.form_field type="text_input" form={f} field={:name} />
            <.form_field type="email_input" form={f} field={:email} />
            <.form_field type="checkbox" form={f} field={:is_onboarded} />
            <.form_field type="checkbox" form={f} field={:is_admin} />

            <div class="flex justify-end">
              <.button size="sm">
                Update
              </.button>
            </div>
          </.form>
        </div>
      </.modal>
    <% end %>
    """
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, patch_back_to_index(socket)}
  end

  def handle_event("update_user", %{"user" => user_params}, socket) do
    case Accounts.update_user_as_admin(socket.assigns.changeset.data, user_params) do
      {:ok, _user} ->
        socket =
          socket
          |> put_flash(:info, "User updated")
          |> patch_back_to_index()

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("suspend_user", params, socket) do
    user = Accounts.get_user!(params["id"])

    case Accounts.suspend_user(user) do
      {:ok, user} ->
        UserAuth.log_out_another_user(user)

        socket =
          socket
          |> put_flash(:info, "User suspended")
          |> patch_back_to_index()

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("undo_suspend_user", params, socket) do
    user = Accounts.get_user!(params["id"])

    case Accounts.undo_suspend_user(user) do
      {:ok, _user} ->
        socket =
          socket
          |> put_flash(:info, "User no longer suspended")
          |> patch_back_to_index()

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("delete_user", params, socket) do
    user = Accounts.get_user!(params["id"])

    case Accounts.delete_user(user) do
      {:ok, user} ->
        UserAuth.log_out_another_user(user)

        socket =
          socket
          |> put_flash(:info, "User deleted")
          |> patch_back_to_index()

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("undo_delete_user", params, socket) do
    user = Accounts.get_user!(params["id"])

    case Accounts.undo_delete_user(user) do
      {:ok, _user} ->
        socket =
          socket
          |> put_flash(:info, "User no longer deleted")
          |> patch_back_to_index()

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp patch_back_to_index(socket) do
    to =
      if socket.assigns[:url] do
        uri = URI.parse(socket.assigns.url)
        uri.path <> "?" <> uri.query
      else
        Routes.admin_users_path(socket, :index)
      end

    push_patch(socket, to: to)
  end

  def user_actions(assigns) do
    ~H"""
    <div class="flex items-center" id={"user_actions_container_#{@user.id}"}>
      <.dropdown options_container_id={"user_options_#{@user.id}"}>
        <.dropdown_menu_item
          link_type="live_patch"
          label="Edit"
          to={Routes.admin_users_path(@socket, :edit, @user)}
        />

        <.dropdown_menu_item
          link_type="live_redirect"
          label="View logs"
          to={Routes.logs_path(@socket, :index, user_id: @user.id)}
        />

        <%= if @user.is_suspended do %>
          <.dropdown_menu_item
            label="Undo suspend"
            phx-click={
              JS.push("undo_suspend_user")
              |> JS.hide(to: "#user_options_#{@user.id}")
            }
            phx-value-id={@user.id}
            data-confirm="Are you sure?"
          />
        <% else %>
          <.dropdown_menu_item
            label="Suspend"
            phx-click={
              JS.push("suspend_user")
              |> JS.hide(to: "#user_options_#{@user.id}")
            }
            phx-value-id={@user.id}
            data-confirm={
              "Are you sure? #{user_name(@user)} will be logged out and unable to sign in."
            }
          />
        <% end %>

        <%= if @user.is_deleted do %>
          <.dropdown_menu_item
            label="Undo delete"
            phx-click={
              JS.push("undo_delete_user")
              |> JS.hide(to: "#user_options_#{@user.id}")
            }
            phx-value-id={@user.id}
            data-confirm="Are you sure?"
          />
        <% else %>
          <.dropdown_menu_item
            label="Delete"
            phx-click={
              JS.hide(to: "#user_options_#{@user.id}")
              |> JS.push("delete_user")
            }
            phx-value-id={@user.id}
            data-confirm="Are you sure?"
          />
        <% end %>
      </.dropdown>
    </div>
    """
  end
end
