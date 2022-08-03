defmodule PanicWeb.EditProfileLiveTest do
  use PanicWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Panic.Repo

  describe "when signed in" do
    setup :register_and_sign_in_user

    test "event update_profile works", %{conn: conn, user: user} do
      {:ok, view, html} = live(conn, Routes.live_path(conn, PanicWeb.EditProfileLive))
      assert html =~ "Name"

      assert view
             |> form("#update_profile_form", user: %{name: "123456789"})
             |> render_submit() =~ "Profile updated"

      user = Panic.Accounts.get_user!(user.id)
      assert user.name == "123456789"

      log = Repo.last(Panic.Logs.Log)
      assert log.user_id == user.id
      assert log.action == "update_profile"
    end
  end

  describe "when signed out" do
    test "can't access the page", %{conn: conn} do
      live(conn, Routes.live_path(conn, PanicWeb.EditProfileLive))
      |> assert_route_protected()
    end
  end
end
