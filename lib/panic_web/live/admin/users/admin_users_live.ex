defmodule PanicWeb.AdminUsersLive do
  @moduledoc """
  A live view to admin users on the platform (edit/suspend/delete).
  """
  use PanicWeb, :live_view
  alias Panic.{Accounts, Repo}
  alias Panic.Accounts.UserQuery
  alias PanicWeb.AdminUsersLive.UserFilterChangeset
  alias PanicWeb.UserAuth
  alias PetalFramework.Extensions.Ecto.{QueryExt}
  import PanicWeb.AdminLayoutComponent

  def mount(params, _session, socket) do
    socket =
      socket
      |> assign(
        user_filter_changeset: UserFilterChangeset.build(params),
        page_title: "Admin users",
        load_more: false,
        limit: 25,
        total_count: nil,
        loading: true,
        users: []
      )

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, socket |> apply_action(socket.assigns.live_action, params)}
  end

  def apply_action(socket, :index, params) do
    socket =
      socket
      |> assign(%{
        user_filter_changeset: UserFilterChangeset.build(params),
        page_title: "Admin users",
        changeset: nil
      })

    # Only fetch all users when the socket is connected to save on unnessesary db calls
    if connected?(socket) do
      socket
      |> assign(loading: false)
      |> assign_users()
    else
      assign(socket, loading: true, users: [])
    end
  end

  def apply_action(socket, :edit, %{"user_id" => user_id}) do
    user = Accounts.get_user!(user_id)

    assign(socket, %{
      page_title: "Edit #{user.name}",
      loading: false,
      changeset: Accounts.change_user_as_admin(user)
    })
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, push_patch(socket, to: Routes.admin_users_path(socket, :index))}
  end

  def handle_event("search", %{"user_filter" => user_filter_params}, socket) do
    {:noreply,
     push_patch(socket,
       to: Routes.admin_users_path(socket, :index, user_filter_params)
     )}
  end

  def handle_event("load_more", _, socket) do
    socket =
      socket
      |> update(:limit, fn limit -> limit + 25 end)
      |> assign_users()

    {:noreply, socket}
  end

  def handle_event("update_user", %{"user" => user_params}, socket) do
    case Accounts.update_user_as_admin(socket.assigns.changeset.data, user_params) do
      {:ok, user} ->
        socket =
          socket
          |> put_flash(:info, "User updated")
          |> push_patch(to: Routes.admin_users_path(socket, :index))
          |> assign(
            changeset: nil,
            users: Util.replace_object_in_list(socket.assigns.users, user)
          )

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("suspend_user", params, socket) do
    user = Enum.find(socket.assigns.users, &(&1.id == String.to_integer(params["id"])))

    case Accounts.suspend_user(user) do
      {:ok, user} ->
        UserAuth.log_out_another_user(user)

        socket =
          socket
          |> put_flash(:info, "User suspended")
          |> push_patch(to: Routes.admin_users_path(socket, :index))
          |> assign(
            changeset: nil,
            users: Util.replace_object_in_list(socket.assigns.users, user)
          )

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("undo_suspend_user", params, socket) do
    user = Enum.find(socket.assigns.users, &(&1.id == String.to_integer(params["id"])))

    case Accounts.undo_suspend_user(user) do
      {:ok, user} ->
        socket =
          socket
          |> put_flash(:info, "User no longer suspended")
          |> push_patch(to: Routes.admin_users_path(socket, :index))
          |> assign(
            changeset: nil,
            users: Util.replace_object_in_list(socket.assigns.users, user)
          )

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("delete_user", params, socket) do
    user = Enum.find(socket.assigns.users, &(&1.id == String.to_integer(params["id"])))

    case Accounts.delete_user(user) do
      {:ok, user} ->
        UserAuth.log_out_another_user(user)

        socket =
          socket
          |> put_flash(:info, "User deleted")
          |> push_patch(to: Routes.admin_users_path(socket, :index))
          |> assign(
            changeset: nil,
            users: Enum.reject(socket.assigns.users, &(&1.id == user.id))
          )

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("undo_delete_user", params, socket) do
    user = Enum.find(socket.assigns.users, &(&1.id == String.to_integer(params["id"])))

    case Accounts.undo_delete_user(user) do
      {:ok, user} ->
        socket =
          socket
          |> put_flash(:info, "User no longer deleted")
          |> push_patch(to: Routes.admin_users_path(socket, :index))
          |> assign(
            changeset: nil,
            users: Enum.reject(socket.assigns.users, &(&1.id == user.id))
          )

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def assign_users(socket) do
    case UserFilterChangeset.validate(socket.assigns.user_filter_changeset) do
      {:ok, user_filter} ->
        query =
          UserQuery.text_search(user_filter.text_search)
          |> UserQuery.is_deleted(user_filter.is_deleted)

        query =
          if user_filter.is_suspended,
            do: UserQuery.is_suspended(query),
            else: query

        total_count = Repo.count(query)

        users =
          query
          |> QueryExt.limit(socket.assigns.limit)
          |> QueryExt.order_newest_first()
          |> Repo.all()

        assign(socket, total_count: total_count, users: users)

      {:error, changeset} ->
        assign(socket, %{
          user_filter_changeset: changeset,
          users: []
        })
    end
  end
end
