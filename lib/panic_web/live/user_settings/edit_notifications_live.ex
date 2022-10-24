defmodule PanicWeb.EditNotificationsLive do
  use PanicWeb, :live_view
  import PanicWeb.UserSettingsLayoutComponent
  alias Panic.Accounts
  alias Panic.Accounts.User

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       changeset: User.profile_changeset(socket.assigns.current_user)
     )}
  end

  def render(assigns) do
    ~H"""
    <.settings_layout current_page={:edit_notifications} current_user={@current_user}>
      <.form :let={f} id="update_profile_form" for={@changeset} phx-change="update_profile">
        <.form_field
          type="checkbox"
          form={f}
          field={:is_subscribed_to_marketing_notifications}
          label={gettext("Allow marketing notifications")}
        />
      </.form>
    </.settings_layout>
    """
  end

  def handle_event("update_profile", %{"user" => user_params}, socket) do
    case Accounts.update_profile(socket.assigns.current_user, user_params) do
      {:ok, current_user} ->
        Accounts.user_lifecycle_action("after_update_profile", current_user)

        socket =
          socket
          |> put_flash(:info, gettext("Profile updated"))
          |> assign(current_user: current_user, changeset: User.profile_changeset(current_user))

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> put_flash(:error, gettext("Update failed. Please check the form for issues"))
          |> assign(changeset: changeset)

        {:noreply, socket}
    end
  end
end
