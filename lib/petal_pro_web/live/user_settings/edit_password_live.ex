defmodule PetalProWeb.EditPasswordLive do
  use PetalProWeb, :live_view
  import PetalProWeb.UserSettingsLayoutComponent
  alias PetalPro.Accounts
  alias PetalPro.Accounts.User

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       changeset: User.profile_changeset(socket.assigns.current_user)
     )}
  end

  def render(assigns) do
    ~H"""
    <.settings_layout current={:edit_password} current_user={@current_user}>
      <.form let={f} for={@changeset} action={Routes.user_settings_path(@socket, :update_password)}>
        <.form_field
          type="password_input"
          form={f}
          field={:current_password}
          name="current_password"
          label={gettext("Current password")}
        />

        <.form_field type="password_input" form={f} field={:password} label={gettext("New password")} />

        <.form_field
          type="password_input"
          form={f}
          field={:password_confirmation}
          label={gettext("New password confirmation")}
        />

        <div class="flex justify-between">
          <button
            type="button"
            phx-click="send_password_reset_email"
            data-confirm={
              "This will send a reset password link to the email '#{@current_user.email}'. Continue?"
            }
            class="text-sm text-gray-500 underline dark:text-gray-400"
          >
            Forgot your password?
          </button>

          <.button><%= gettext("Change password") %></.button>
        </div>
      </.form>
    </.settings_layout>
    """
  end

  def handle_event("send_password_reset_email", _, socket) do
    Accounts.deliver_user_reset_password_instructions(
      socket.assigns.current_user,
      &Routes.user_reset_password_url(socket, :edit, &1)
    )

    {:noreply,
     put_flash(
       socket,
       :info,
       gettext("You will receive instructions to reset your password shortly.")
     )}
  end
end
