defmodule PanicWeb.UserLiveTest do
  use PanicWeb.ConnCase

  describe "user can" do
    test "log in", %{conn: conn} do
      password = "abcd1234"
      user = Panic.Fixtures.user(password)

      conn
      |> visit("/sign-in")
      |> fill_in("Email", with: user.email)
      |> fill_in("Password", with: password)
      |> click_button("Sign in")
      |> assert_has("body", text: "Panic is live.")
    end
  end
end
