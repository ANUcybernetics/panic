defmodule PetalProWeb.EditNotificationsLiveTest do
  use PetalProWeb.ConnCase
  import Phoenix.LiveViewTest
  alias PetalPro.Repo

  describe "when signed in" do
    setup :register_and_sign_in_user

    test "can update notifications", %{conn: conn, user: user} do
      {:ok, view, html} = live(conn, Routes.live_path(conn, PetalProWeb.EditNotificationsLive))
      assert html =~ "Allow marketing notifications"
      assert user.is_subscribed_to_marketing_notifications == true

      assert view
             |> form("#update_profile_form",
               user: %{is_subscribed_to_marketing_notifications: false}
             )
             |> render_change() =~ "Profile updated"

      user = PetalPro.Accounts.get_user!(user.id)
      assert user.is_subscribed_to_marketing_notifications == false

      log = Repo.last(PetalPro.Logs.Log)
      assert log.user_id == user.id
      assert log.action == "update_profile"
    end
  end

  describe "when signed out" do
    test "can't access the page", %{conn: conn} do
      live(conn, Routes.live_path(conn, PetalProWeb.EditNotificationsLive))
      |> assert_route_protected()
    end
  end
end
