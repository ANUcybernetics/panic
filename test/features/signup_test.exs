defmodule PetalPro.Features.SignupTest do
  use ExUnit.Case
  use Wallaby.Feature
  alias Wallaby.Query
  import Wallaby.Query

  feature "users can create an account", %{session: session} do
    session =
      session
      |> visit("/register")
      |> assert_has(Query.text("Register"))
      |> fill_in(text_field("user[name]"), with: "Bob")
      |> fill_in(text_field("user[email]"), with: "bob@example.com")
      |> fill_in(text_field("user[password]"), with: "password")
      |> click(button("Create account"))
      |> assert_has(Query.text("Welcome"))
      |> fill_in(text_field("user[name]"), with: "Jerry")
      |> click(button("Submit"))
      |> assert_has(Query.text("Welcome, Jerry"))
      |> assert_has(Query.text("Unconfirmed account"))

    assert current_url(session) =~ "/app"
  end
end
