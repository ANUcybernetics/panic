defmodule PanicWeb.AuthController do
  use PanicWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, _activity, user, _token) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> redirect(to: return_to)
  end

  def failure(conn, _activity, _reason) do
    conn
    |> put_status(401)
    |> render("failure.html")
  end

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/"

    # TODO: This uses the deprecated Plug.Conn.clear_session/1 instead of the
    # AshAuthentication clear_session/2 because we're using session-based
    # authentication without token resources configured. To use the recommended
    # approach, we would need to:
    # 1. Create a token resource (Panic.Accounts.Token)
    # 2. Configure it in the User resource authentication block
    # 3. Run migrations for the tokens table
    # This would be a breaking change affecting the authentication flow,
    # so we're deferring this upgrade to a future refactoring.
    conn
    |> Plug.Conn.clear_session()
    |> redirect(to: return_to)
  end
end
