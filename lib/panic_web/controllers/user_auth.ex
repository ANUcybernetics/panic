defmodule PanicWeb.UserAuth do
  @moduledoc """
  A set of plugs related to user authentication.
  This module is imported into the router and thus any function can be called there as a plug.
  """
  import Plug.Conn
  import Phoenix.Controller
  import PanicWeb.Gettext

  alias Panic.{Repo, Accounts}
  alias PanicWeb.Router.Helpers, as: Routes

  require Logger

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in UserToken.
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_panic_web_user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  def log_in_user(conn, _user, _params \\ %{})

  def log_in_user(conn, %{is_suspended: false, is_deleted: false} = user, params) do
    conn = put_user_into_session(conn, user)
    Accounts.user_lifecycle_action("after_sign_in", user, %{ip: get_ip(conn)})

    # If the user has set up 2FA then we need to redirect to the 2FA page for them to enter their code.
    if Accounts.two_factor_auth_enabled?(user) do
      conn
      |> put_session(:user_totp_pending, true)
      |> redirect(to: Routes.user_totp_path(conn, :new, user: Map.take(params, ["remember_me"])))
    else
      redirect_user_after_login_with_remember_me(conn, user, params)
    end
  end

  def log_in_user(conn, _user, _params) do
    conn =
      put_flash(
        conn,
        :error,
        gettext("There is a problem with your account. Please contact support.")
      )

    redirect(conn, to: Routes.user_session_path(conn, :new))
  end

  @doc "This is what makes a user 'signed in'. Future requests will have user_token in the session and we fetch the current_user based off this."
  def put_user_into_session(conn, user) do
    token = Accounts.generate_user_session_token(user)

    conn
    |> renew_session()
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
  end

  @doc """
  Returns to or redirects home and potentially set remember_me token.
  """
  def redirect_user_after_login_with_remember_me(conn, user, params \\ %{}) do
    user_return_to = get_session(conn, :user_return_to)

    conn =
      conn
      |> maybe_write_remember_me_cookie(params)
      |> delete_session(:user_return_to)

    try do
      redirect(conn, to: user_return_to || signed_in_path(user))
    rescue
      ArgumentError ->
        redirect(conn, to: signed_in_path(user))
    end
  end

  defp maybe_write_remember_me_cookie(conn, %{"remember_me" => "true"}) do
    token = get_session(conn, :user_token)
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _params) do
    conn
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing
  defp renew_session(conn) do
    user_return_to = get_session(conn, :user_return_to)
    locale = get_session(conn, :locale)

    conn
    |> configure_session(renew: true)
    |> clear_session()
    |> put_session(:user_return_to, user_return_to)
    |> put_session(:locale, locale)
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      PanicWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    if conn.assigns[:current_user] do
      Panic.Logs.log_async("sign_out", %{user: conn.assigns.current_user})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: "/")
  end

  @doc """
  Deletes the user's session and forces all live views to reconnect (logging them out fully)
  """
  def log_out_another_user(user) do
    users_tokens = Accounts.UserToken.user_and_contexts_query(user, ["session"]) |> Repo.all()
    disconnect_user_tokens(users_tokens, true)
  end

  @doc """
  Forces all live views to reconnect for a user. Useful if their permissions have changed (eg. no longer an org member).
  """
  def disconnect_user_liveviews(user) do
    users_tokens = Accounts.UserToken.user_and_contexts_query(user, ["session"]) |> Repo.all()
    disconnect_user_tokens(users_tokens)
  end

  defp disconnect_user_tokens(users_tokens, delete_too? \\ false) do
    for user_token <- users_tokens do
      PanicWeb.Endpoint.broadcast(user_session_topic(user_token.token), "disconnect", %{})
      delete_too? && Accounts.delete_session_token(user_token.token)
    end
  end

  defp user_session_topic(token), do: "user_sessions:" <> token

  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    user = user_token && Accounts.get_user_by_session_token(user_token)
    assign(conn, :current_user, user)
  end

  defp ensure_user_token(conn) do
    if user_token = get_session(conn, :user_token) do
      {user_token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if user_token = conn.cookies[@remember_me_cookie] do
        {user_token, put_session(conn, :user_token, user_token)}
      else
        {nil, conn}
      end
    end
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn.assigns[:current_user]))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.
  """
  def require_authenticated_user(conn, opts) do
    cond do
      is_nil(conn.assigns[:current_user]) ->
        conn
        |> put_flash(:error, gettext("You must log in to access this page."))
        |> maybe_store_return_to()
        |> redirect(to: Routes.user_session_path(conn, :new))
        |> halt()

      get_session(conn, :user_totp_pending) &&
        conn.request_path != Routes.user_totp_path(conn, :new) &&
          conn.request_path != Routes.user_session_path(conn, :delete) ->
        conn
        |> redirect(to: Routes.user_totp_path(conn, :new))
        |> halt()

      true ->
        # SETUP_TODO: this function `require_authenticated_user` is a plug that you use in your router to protect routes to only authorized users.
        # One question is, if a user signs up with an email/pw are they then authenticated? Or is only after they confirm their email?
        # By default we force every user to confirm their email before they can access protected routes. They are redirected to a page telling them to confirm their email.
        # If you don't mind unconfirmed email users accessing your protected routes, then replace the next line with just `conn`:
        require_confirmed_user(conn, opts)
    end
  end

  @doc """
  Used for routes that require the user to be confirmed.
  """
  def require_confirmed_user(conn, _opts) do
    if conn.assigns[:current_user] && conn.assigns[:current_user].confirmed_at do
      conn
    else
      conn
      |> redirect(to: Routes.user_confirmation_path(conn, :unconfirmed))
      |> halt()
    end
  end

  @doc """
  Used for routes that require the user to be a admin
  """
  def require_admin_user(conn, _opts) do
    if conn.assigns[:current_user] && conn.assigns[:current_user].is_admin do
      conn
    else
      conn
      |> put_flash(:error, gettext("You do not have access to this page."))
      |> redirect(to: "/")
      |> halt()
    end
  end

  def kick_user_if_suspended_or_deleted(conn, opts \\ []) do
    if not is_nil(conn.assigns[:current_user]) and
         (conn.assigns[:current_user].is_suspended or
            conn.assigns[:current_user].is_deleted) do
      conn
      |> put_flash(
        :error,
        Keyword.get(opts, :flash, gettext("Your account is not accessible."))
      )
      |> log_out_user
      |> halt()
    else
      conn
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(current_user), do: PanicWeb.Helpers.home_path(current_user)

  defp get_ip(conn) do
    # When behind a load balancer, the client ip is provided in the x-forwarded-for header
    # examples:
    # X-Forwarded-For: 2001:db8:85a3:8d3:1319:8a2e:370:7348
    # X-Forwarded-For: 203.0.113.195
    # X-Forwarded-For: 203.0.113.195, 70.41.3.18, 150.172.238.178
    forwarded_for = List.first(Plug.Conn.get_req_header(conn, "x-forwarded-for"))

    if forwarded_for do
      String.split(forwarded_for, ",")
      |> Enum.map(&String.trim/1)
      |> List.first()
    else
      to_string(:inet_parse.ntoa(conn.remote_ip))
    end
  end
end
