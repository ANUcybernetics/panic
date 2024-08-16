defmodule PanicWeb.UserLiveTest do
  use PanicWeb.ConnCase

  describe "logged in user can" do
    test "user can log in", %{conn: conn} do
      conn
      |> visit("/sign-in")
      |> fill_in("Email", with: "ben@benswift.me")
      |> fill_in("Password", with: "asdfjkl;")
      |> submit()
      |> assert_has(".email", text: "ben@benswift.me")
    end
  end
end
