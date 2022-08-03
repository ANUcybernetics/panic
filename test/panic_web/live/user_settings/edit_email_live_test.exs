defmodule PanicWeb.EditEmailLiveTest do
  use PanicWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "when signed in" do
    setup :register_and_sign_in_user

    test "event update_email works", %{conn: conn, user: _user} do
      new_email = "new_email@example.com"
      {:ok, view, html} = live(conn, Routes.live_path(conn, PanicWeb.EditEmailLive))
      assert html =~ "Change your email"

      assert view
             |> form("#change_email_form", user: %{email: new_email})
             |> render_submit() =~
               "A link to confirm your e-mail change has been sent to the new address"

      assert_email_sent(subject: "Change email")
      assert_log("request_new_email", %{metadata: %{"new_email" => new_email}})
    end
  end

  describe "when signed out" do
    test "can't access the page", %{conn: conn} do
      live(conn, Routes.live_path(conn, PanicWeb.EditEmailLive))
      |> assert_route_protected()
    end
  end
end
