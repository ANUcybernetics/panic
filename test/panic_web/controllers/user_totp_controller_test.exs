defmodule PanicWeb.UserTOTPControllerTest do
  use PanicWeb.ConnCase, async: true

  import Panic.AccountsFixtures
  @pending :user_totp_pending

  setup %{conn: conn} do
    user = confirmed_user_fixture(%{is_onboarded: true})
    conn = conn |> log_in_user(user) |> put_session(@pending, true)
    %{user: user, totp: user_totp_fixture(user), conn: conn}
  end

  describe "GET /users/totp" do
    test "renders totp page", %{conn: conn} do
      conn = get(conn, Routes.user_totp_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "Two-factor authentication"
    end

    test "reads remember from URL", %{conn: conn} do
      conn = get(conn, Routes.user_totp_path(conn, :new), user: [remember_me: "true"])
      response = html_response(conn, 200)

      assert response =~ "checkbox"
      assert response =~ "user[remember_me]"
    end

    test "redirects to login if not logged in" do
      conn = build_conn()

      assert conn
             |> get(Routes.user_totp_path(conn, :new))
             |> redirected_to() ==
               Routes.user_session_path(conn, :new)
    end

    test "can sign out while totp is pending", %{conn: conn} do
      conn = delete(conn, Routes.user_session_path(conn, :delete))
      assert redirected_to(conn) == "/"
      refute get_session(conn, :user_token)
      assert get_flash(conn, :info) =~ "Signed out successfully"
    end

    test "redirects to dashboard if totp is not pending", %{conn: conn, user: user} do
      assert conn
             |> delete_session(@pending)
             |> get(Routes.user_totp_path(conn, :new))
             |> redirected_to() ==
               PanicWeb.Helpers.home_path(user)
    end
  end

  describe "POST /users/totp" do
    test "validates totp", %{conn: conn, totp: totp, user: user} do
      code = NimbleTOTP.verification_code(totp.secret)
      conn = post(conn, Routes.user_totp_path(conn, :create), %{"user" => %{"code" => code}})
      assert_log("totp.validate", user_id: user.id)
      assert redirected_to(conn) == PanicWeb.Helpers.home_path(user)
      assert get_session(conn, @pending) == nil
    end

    test "validates backup code with flash message", %{conn: conn, totp: totp, user: user} do
      code = Enum.random(totp.backup_codes).code

      new_conn = post(conn, Routes.user_totp_path(conn, :create), %{"user" => %{"code" => code}})
      assert redirected_to(new_conn) == PanicWeb.Helpers.home_path(user)
      assert get_session(new_conn, @pending) == nil
      assert get_flash(new_conn, :info) =~ "You have 9 backup codes left"
      assert_log("totp.validate_with_backup_code", user_id: user.id)

      # Cannot reuse the code
      new_conn = post(conn, Routes.user_totp_path(conn, :create), %{"user" => %{"code" => code}})
      assert html_response(new_conn, 200) =~ "Invalid two-factor authentication code"
      assert get_session(new_conn, @pending)
      assert_log("totp.invalid_code_used", user_id: user.id)
    end

    test "logs the user in with remember me", %{conn: conn, totp: totp, user: user} do
      code = Enum.random(totp.backup_codes).code

      conn =
        post(conn, Routes.user_totp_path(conn, :create), %{
          "user" => %{"code" => code, "remember_me" => "true"}
        })

      assert redirected_to(conn) == PanicWeb.Helpers.home_path(user)
      assert get_session(conn, @pending) == nil
      assert conn.resp_cookies["_panic_web_user_remember_me"]
    end

    test "logs the user in with return to", %{conn: conn, totp: totp} do
      code = Enum.random(totp.backup_codes).code

      conn =
        conn
        |> put_session(:user_return_to, "/hello")
        |> post(Routes.user_totp_path(conn, :create), %{"user" => %{"code" => code}})

      assert redirected_to(conn) == "/hello"
      assert get_session(conn, @pending) == nil
    end
  end
end
