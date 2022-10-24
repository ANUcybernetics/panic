defmodule PanicWeb.UserConfirmationController do
  use PanicWeb, :controller

  alias Panic.Accounts

  def new(conn, _params) do
    render(conn, "new.html")
  end

  def resend_confirm_email(conn, _) do
    if is_nil(conn.assigns[:current_user]) do
      conn
      |> put_flash(:error, gettext("You must be signed in to resend confirmation instructions."))
      |> redirect(to: "/")
    else
      if conn.assigns.current_user.confirmed_at do
        conn
        |> put_flash(:info, gettext("You are already confirmed."))
        |> redirect(to: PanicWeb.Helpers.home_path(conn.assigns[:current_user]))
      else
        Accounts.deliver_user_confirmation_instructions(
          conn.assigns.current_user,
          &Routes.user_confirmation_url(conn, :edit, &1)
        )

        conn
        |> put_flash(
          :info,
          gettext("A new email has been sent to %{user_email}",
            user_email: conn.assigns.current_user.email
          )
        )
        |> redirect(to: Routes.user_confirmation_path(conn, :unconfirmed))
      end
    end
  end

  def edit(conn, %{"token" => token}) do
    render(conn, "edit.html", token: token)
  end

  # Do not log in the user after confirmation to avoid a
  # leaked token giving the user access to the account.
  def update(conn, %{"token" => token}) do
    case Accounts.confirm_user(token) do
      {:ok, user} ->
        Accounts.user_lifecycle_action("after_confirm_email", user)

        if conn.assigns[:current_user] do
          conn
          |> put_flash(:info, gettext("User confirmed successfully."))
          |> redirect(to: PanicWeb.Helpers.home_path(conn.assigns[:current_user]))
        else
          conn
          |> put_flash(:info, gettext("User confirmed successfully."))
          |> redirect(to: Routes.user_session_path(conn, :new))
        end

      :error ->
        # If there is a current user and the account was already confirmed,
        # then odds are that the confirmation link was already visited, either
        # by some automation or by the user themselves, so we redirect without
        # a warning message.
        case conn.assigns do
          %{current_user: %{confirmed_at: confirmed_at}} when not is_nil(confirmed_at) ->
            redirect(conn, to: "/")

          %{} ->
            conn
            |> put_flash(:error, gettext("User confirmation link is invalid or it has expired."))
            |> redirect(to: "/")
        end
    end
  end

  def unconfirmed(conn, _) do
    cond do
      !conn.assigns[:current_user] ->
        redirect(conn, to: "/")

      conn.assigns.current_user.confirmed_at ->
        redirect(conn, to: PanicWeb.Helpers.home_path(conn.assigns.current_user))

      true ->
        render(conn, page_title: gettext("Unconfirmed email"))
    end
  end
end
