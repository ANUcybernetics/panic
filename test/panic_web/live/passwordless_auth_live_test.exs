defmodule PanicWeb.PasswordlessAuthLiveTest do
  use PanicWeb.ConnCase
  import Phoenix.LiveViewTest
  import Panic.AccountsFixtures
  alias Panic.Repo

  describe "no existing user" do
    test "it creates a new user and logs them in", %{conn: conn} do
      inital_user_count = Repo.count(Panic.Accounts.User)
      {:ok, view, _html} = live(conn, Routes.passwordless_auth_path(conn, :sign_in))
      email = unique_user_email()

      # Enter in our email
      html =
        view
        |> form("form", user: %{email: email})
        |> render_submit()

      # A new user should have been created
      assert inital_user_count + 1 == Repo.count(Panic.Accounts.User)
      new_user = Repo.last(Panic.Accounts.User)
      assert new_user.email == email

      # Check that the view now shows the pin entering screen
      assert_patch(view)
      assert html =~ email
      assert html =~ "Check your email"

      # Check that an email was sent to the email address
      assert_received {:email, swoosh_email}

      # Extract the pin out of the email
      pin = Regex.run(~r/\d{6}/, swoosh_email.text_body) |> Enum.at(0)

      # Submit the pin, which will set phx-trigger-action
      assert view
             |> form("form")
             |> render_change(%{auth: %{pin: pin}}) =~ ~r/phx-trigger-action/

      # Normally the presence of phx-trigger-action would cause live views javascript to submit our form for us.
      # But since we're not in a browser environment we need to manually submit it
      sign_in_token =
        new_user
        |> Panic.Accounts.generate_user_session_token()
        |> Base.encode64()

      form = form(view, "form", %{"auth" => %{"sign_in_token" => sign_in_token}})
      conn = follow_trigger_action(form, conn)
      assert redirected_to(conn) =~ PanicWeb.Helpers.home_path(new_user)

      # New user should be confirmed, as they obviously have access to their email
      new_user = Repo.last(Panic.Accounts.User)
      assert !!new_user.confirmed_at
    end
  end

  describe "with existing user" do
    test "it logs in the existing user", %{conn: conn} do
      user = confirmed_user_fixture()
      inital_user_count = Repo.count(Panic.Accounts.User)

      {:ok, view, _html} = live(conn, Routes.passwordless_auth_path(conn, :sign_in))

      html =
        view
        |> form("form", user: %{email: user.email})
        |> render_submit()

      assert_patch(view)
      assert html =~ user.email
      assert html =~ "Check your email"

      assert_received {:email, swoosh_email}
      pin = Regex.run(~r/\d{6}/, swoosh_email.text_body) |> Enum.at(0)

      assert view
             |> form("form")
             |> render_change(%{auth: %{pin: pin}}) =~ ~r/phx-trigger-action/

      sign_in_token =
        user
        |> Panic.Accounts.generate_user_session_token()
        |> Base.encode64()

      form =
        form(view, "form", %{
          "auth" => %{"sign_in_token" => sign_in_token, "user_return_to" => ""}
        })

      conn = follow_trigger_action(form, conn)
      assert redirected_to(conn) =~ PanicWeb.Helpers.home_path(user)
      assert inital_user_count == Repo.count(Panic.Accounts.User)
    end
  end
end
