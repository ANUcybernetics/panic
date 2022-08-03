defmodule PanicWeb.UserOnboardingLiveTest do
  use PanicWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Panic.Repo

  describe "when signed in" do
    setup :register_and_sign_in_user

    test "user can update their details", %{conn: conn, user: user} do
      {:ok, view, html} = live(conn, Routes.live_path(conn, PanicWeb.UserOnboardingLive))

      assert html =~ "Welcome!"

      view
      |> form("#update_profile_form",
        user: %{name: "123456789", is_subscribed_to_marketing_notifications: false}
      )
      |> render_submit()

      {path, flash} = assert_redirect(view)
      assert path == PanicWeb.Helpers.home_path(user)
      assert flash["info"] == "Thank you!"

      user = Panic.Accounts.get_user!(user.id)
      assert user.name == "123456789"
      assert user.is_subscribed_to_marketing_notifications == false

      log = Repo.last(Panic.Logs.Log)
      assert log.user_id == user.id
      assert log.action == "update_profile"
    end

    test "redirects to user_return_to", %{conn: conn} do
      user_return_to = "/go-here-after-onboarding"

      {:ok, view, _html} =
        live(
          conn,
          Routes.live_path(conn, PanicWeb.UserOnboardingLive, user_return_to: user_return_to)
        )

      view
      |> form("#update_profile_form",
        user: %{name: "123456789", is_subscribed_to_marketing_notifications: false}
      )
      |> render_submit()

      {path, flash} = assert_redirect(view)
      assert path == user_return_to
      assert flash["info"] == "Thank you!"
    end
  end

  describe "when signed out" do
    test "can't access the page", %{conn: conn} do
      live(conn, Routes.live_path(conn, PanicWeb.UserOnboardingLive))
      |> assert_route_protected()
    end
  end
end
