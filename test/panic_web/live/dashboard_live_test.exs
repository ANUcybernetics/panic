defmodule PanicWeb.DashboardLiveTest do
  use PanicWeb.ConnCase
  import Phoenix.LiveViewTest

  setup :register_and_sign_in_user

  test "renders the user's name", %{conn: conn, user: user} do
    {:ok, _view, html} = live(conn, Routes.live_path(conn, PanicWeb.DashboardLive))
    assert html =~ user.name
  end
end
