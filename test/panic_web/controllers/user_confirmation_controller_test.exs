defmodule PanicWeb.UserConfirmationControllerTest do
  use PanicWeb.ConnCase, async: true

  alias Panic.Accounts
  alias Panic.Repo
  import Panic.AccountsFixtures

  setup do
    %{user: user_fixture()}
  end

  describe "GET /users/unconfirmed" do
    test "renders the unconfirmed page", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      conn = get(conn, Routes.user_confirmation_path(conn, :unconfirmed))
      response = html_response(conn, 200)
      assert response =~ "Resend confirmation instructions"
    end
  end

  describe "POST /users/resend_confirm_email" do
    @tag :capture_log
    test "sends a new confirmation token", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      conn = post(conn, Routes.user_confirmation_path(conn, :resend_confirm_email), %{})

      assert redirected_to(conn) == Routes.user_confirmation_path(conn, :unconfirmed)
      assert get_flash(conn, :info) =~ "A new email has been sent"

      assert Panic.Accounts.UserToken.user_and_contexts_query(user, ["confirm"])
             |> Repo.all()
             |> List.first()
    end

    test "does not send confirmation token if User is confirmed", %{conn: conn, user: user} do
      Repo.update!(Accounts.User.confirm_changeset(user))
      conn = log_in_user(conn, user)
      conn = post(conn, Routes.user_confirmation_path(conn, :resend_confirm_email), %{})

      assert redirected_to(conn) == PanicWeb.Helpers.home_path(user)
      assert get_flash(conn, :info) =~ "You are already confirmed"
      assert html_response(conn, 302)
    end

    test "does not send confirmation token if user is not signed in", %{conn: conn} do
      conn = post(conn, Routes.user_confirmation_path(conn, :resend_confirm_email), %{})

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "You must be signed in"
      assert Repo.all(Accounts.UserToken) == []
    end
  end

  describe "GET /users/confirm/:token" do
    test "renders the confirmation page", %{conn: conn} do
      conn = get(conn, Routes.user_confirmation_path(conn, :edit, "some-token"))
      response = html_response(conn, 200)
      assert response =~ "Confirm account"

      form_action = Routes.user_confirmation_path(conn, :update, "some-token")
      assert response =~ "action=\"#{form_action}\""
    end
  end

  describe "POST /users/confirm/:token" do
    test "confirms the given token once", %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      conn = post(conn, Routes.user_confirmation_path(conn, :update, token))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
      assert get_flash(conn, :info) =~ "User confirmed successfully"
      assert Accounts.get_user!(user.id).confirmed_at
      refute get_session(conn, :user_token)
      assert Repo.all(Accounts.UserToken) == []

      # When not logged in
      conn = post(conn, Routes.user_confirmation_path(conn, :update, token))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "User confirmation link is invalid or it has expired"

      # When logged in
      conn =
        build_conn()
        |> log_in_user(user)
        |> post(Routes.user_confirmation_path(conn, :update, token))

      assert redirected_to(conn) == "/"
      refute get_flash(conn, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, user: user} do
      conn = post(conn, Routes.user_confirmation_path(conn, :update, "oops"))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "User confirmation link is invalid or it has expired"
      refute Accounts.get_user!(user.id).confirmed_at
    end
  end
end
