defmodule Panic.Features.SignupTest do
  use ExUnit.Case
  use Wallaby.Feature
  alias Wallaby.Query
  import Wallaby.Query
  import Panic.AccountsFixtures
  alias PanicWeb.Endpoint
  alias PanicWeb.Router.Helpers, as: Routes

  feature "users can create an account", %{session: session} do
    session =
      session
      |> visit(Routes.user_registration_path(Endpoint, :new))
      |> assert_has(Query.text("Register"))
      |> fill_in(text_field("user[name]"), with: "Bob")
      |> fill_in(text_field("user[email]"), with: "bob@example.com")
      |> fill_in(text_field("user[password]"), with: "password")
      |> click(button("Create account"))
      |> assert_has(Query.text("Email confirmation required"))

    assert current_path(session) =~ "/auth/unconfirmed"
  end

  feature "users get onboarded if user.is_onboarded is false", %{session: session} do
    user = confirmed_user_fixture(%{is_onboarded: false})

    session =
      session
      |> visit(Routes.user_session_path(Endpoint, :new))
      |> fill_in(text_field("user[email]"), with: user.email)
      |> fill_in(text_field("user[password]"), with: "password")
      |> click(button("Sign in"))
      |> assert_has(Query.text("Welcome"))
      |> fill_in(text_field("user[name]"), with: "Jerry")
      |> click(button("Submit"))
      |> assert_has(Query.text("Welcome, Jerry"))

    assert current_path(session) =~ "/app"
  end

  feature "users don't get onboarded if user.is_onboarded is true", %{session: session} do
    user = confirmed_user_fixture(%{is_onboarded: true})

    session =
      session
      |> visit(Routes.user_session_path(Endpoint, :new))
      |> fill_in(text_field("user[email]"), with: user.email)
      |> fill_in(text_field("user[password]"), with: "password")
      |> click(button("Sign in"))

    assert current_path(session) =~ "/app"
  end
end
