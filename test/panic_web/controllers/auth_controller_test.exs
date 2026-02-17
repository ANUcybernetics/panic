defmodule PanicWeb.AuthControllerTest do
  use PanicWeb.ConnCase, async: false
  use ExUnitProperties

  import PanicWeb.Helpers

  alias Panic.Fixtures

  describe "authentication flows" do
    test "user can sign in with valid credentials", %{conn: conn} do
      password = "password123"
      user = Fixtures.user(password)

      conn
      |> visit("/sign-in")
      |> fill_in("Email", with: user.email)
      |> fill_in("Password", with: password)
      |> submit()
      |> assert_has("a", text: "About")
    end

    test "user sees error with invalid credentials", %{conn: conn} do
      password = "password123"
      user = Fixtures.user(password)

      conn
      |> visit("/sign-in")
      |> fill_in("Email", with: user.email)
      |> fill_in("Password", with: "wrong password")
      |> submit()
      |> assert_has("h1", text: "Authentication Error")
    end

    test "user can sign out", %{conn: conn} do
      %{conn: conn} = create_and_sign_in_user(%{conn: conn})

      conn
      |> visit("/users")
      |> assert_has("h1", text: "Listing Users")

      conn = get(conn, "/sign-out")
      assert redirected_to(conn) == "/"

      Phoenix.ConnTest.build_conn()
      |> visit("/users")
      |> assert_has("button", text: "Sign in")
    end

    test "sign in redirects to originally requested page", %{conn: conn} do
      password = "password123"
      user = Fixtures.user(password)

      conn
      |> visit("/users")
      |> assert_has("button", text: "Sign in")
      |> fill_in("Email", with: user.email)
      |> fill_in("Password", with: password)
      |> submit()
      |> then(fn session ->
        session |> visit("/users") |> assert_has("h1", text: "Listing Users")
      end)
    end

    test "password reset page renders", %{conn: conn} do
      token = Phoenix.Token.sign(PanicWeb.Endpoint, "reset_token", %{})

      conn
      |> visit(~p"/password-reset/#{token}")
    end

    test "anonymous user cannot access protected routes", %{conn: conn} do
      conn
      |> visit("/users")
      |> assert_has("button", text: "Sign in")
    end

    test "authenticated user can access protected routes", %{conn: conn} do
      %{conn: conn} = create_and_sign_in_user(%{conn: conn})

      conn
      |> visit("/users")
      |> assert_has("h1", text: "Listing Users")
    end

    test "sign in page is accessible when not authenticated", %{conn: conn} do
      conn
      |> visit("/sign-in")
      |> assert_has("button", text: "Sign in")
    end
  end
end
