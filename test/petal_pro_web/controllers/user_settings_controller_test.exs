defmodule PetalProWeb.UserSettingsControllerTest do
  use PetalProWeb.ConnCase, async: true

  alias PetalPro.Accounts
  import PetalPro.AccountsFixtures

  setup :register_and_sign_in_user

  describe "PUT /users/settings (change password form)" do
    test "updates the user password and resets tokens", %{conn: conn, user: user} do
      new_password_conn =
        put(conn, Routes.user_settings_path(conn, :update_password), %{
          "current_password" => valid_user_password(),
          "user" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(new_password_conn) ==
               Routes.live_path(conn, PetalProWeb.EditPasswordLive)

      assert get_session(new_password_conn, :user_token) != get_session(conn, :user_token)
      assert get_flash(new_password_conn, :info) =~ "Password updated successfully"
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "does not update password on invalid data", %{conn: conn} do
      old_password_conn =
        put(conn, Routes.user_settings_path(conn, :update_password), %{
          "current_password" => "invalid",
          "user" => %{
            "password" => "short",
            "password_confirmation" => "does not match"
          }
        })

      assert html_response(old_password_conn, 302)
      assert get_flash(old_password_conn, :error) =~ "does not match password"
      assert get_flash(old_password_conn, :error) =~ "is not valid"

      assert get_session(old_password_conn, :user_token) == get_session(conn, :user_token)
    end
  end

  describe "GET /users/settings/confirm_email/:token" do
    setup %{user: user} do
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{token: token, email: email}
    end

    test "updates the user email once", %{conn: conn, user: user, token: token, email: email} do
      conn = get(conn, Routes.user_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.live_path(conn, PetalProWeb.EditProfileLive)
      assert get_flash(conn, :info) =~ "Email changed successfully"
      refute Accounts.get_user_by_email(user.email)
      assert Accounts.get_user_by_email(email)

      conn = get(conn, Routes.user_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.live_path(conn, PetalProWeb.EditProfileLive)
      assert get_flash(conn, :error) =~ "Email change link is invalid or it has expired"
    end

    test "does not update email with invalid token", %{conn: conn, user: user} do
      conn = get(conn, Routes.user_settings_path(conn, :confirm_email, "oops"))
      assert redirected_to(conn) == Routes.live_path(conn, PetalProWeb.EditProfileLive)
      assert get_flash(conn, :error) =~ "Email change link is invalid or it has expired"
      assert Accounts.get_user_by_email(user.email)
    end

    test "redirects if user is not logged in", %{token: token} do
      conn = build_conn()
      conn = get(conn, Routes.user_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
    end
  end

  describe "GET /users/unsubscribe/:code/:notification_subscription" do
    test "renders an unsubscribe page for that notification subscription", %{
      conn: conn,
      user: user
    } do
      unsub_url =
        PetalPro.Accounts.NotificationSubscriptions.unsubscribe_url(
          user,
          :marketing_notifications
        )

      conn = get(conn, unsub_url)
      response = html_response(conn, 200)
      assert response =~ "Confirm unsubscribe"

      assert response =~
               PetalPro.Accounts.NotificationSubscriptions.get("marketing_notifications").label
    end
  end

  describe "PUT /users/unsubscribe/:code/:notification_subscription" do
    test "toggles the notification subscription on/off", %{conn: conn, user: user} do
      assert {:ok, user} =
               Accounts.update_profile(user, %{is_subscribed_to_marketing_notifications: true})

      unsub_url =
        PetalPro.Accounts.NotificationSubscriptions.unsubscribe_url(
          user,
          :marketing_notifications
        )

      conn = put(conn, unsub_url)
      assert html_response(conn, 302)
      user = Accounts.get_user!(user.id)
      assert user.is_subscribed_to_marketing_notifications == false
    end
  end
end
