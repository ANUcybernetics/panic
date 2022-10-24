defmodule PanicWeb.UserTOTPController do
  use PanicWeb, :controller

  alias Panic.Accounts
  alias PanicWeb.UserAuth

  plug :redirect_if_totp_is_not_pending

  @pending :user_totp_pending

  def new(conn, _params) do
    render(conn, "new.html", error_message: nil)
  end

  def create(conn, %{"user" => user_params}) do
    current_user = conn.assigns.current_user

    case Accounts.validate_user_totp(current_user, user_params["code"]) do
      :valid_totp ->
        Panic.Logs.log("totp.validate", %{user: current_user})

        conn
        |> delete_session(@pending)
        |> UserAuth.redirect_user_after_login_with_remember_me(current_user, user_params)

      {:valid_backup_code, remaining} ->
        Panic.Logs.log("totp.validate_with_backup_code", %{user: current_user})
        plural = ngettext("backup code", "backup codes", remaining)

        conn
        |> delete_session(@pending)
        |> put_flash(
          :info,
          gettext(
            "You have %{remaining} %{plural} left. You can generate new ones under the Two-factor authentication section in the Settings page",
            remaining: remaining,
            plural: plural
          )
        )
        |> UserAuth.redirect_user_after_login_with_remember_me(current_user, user_params)

      :invalid ->
        Panic.Logs.log("totp.invalid_code_used", %{user: current_user})
        render(conn, "new.html", error_message: gettext("Invalid two-factor authentication code"))
    end
  end

  defp redirect_if_totp_is_not_pending(conn, _opts) do
    if get_session(conn, @pending) do
      conn
    else
      conn
      |> redirect(to: PanicWeb.Helpers.home_path(conn.assigns.current_user))
      |> halt()
    end
  end
end
