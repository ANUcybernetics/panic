defmodule PanicWeb.RedirectLiveTest do
  use PanicWeb.ConnCase, async: false

  import PanicWeb.Helpers
  import Phoenix.LiveViewTest

  describe "Redirect functionality" do
    test "redirects static invocation pattern for anonymous users", %{conn: conn} do
      redirect_param = "s12345"

      assert {:error, {:live_redirect, %{to: "/display/static/12345/"}}} =
               live(conn, ~p"/r/#{redirect_param}")
    end

    test "redirects static invocation pattern for authenticated users", %{conn: conn} do
      %{conn: conn} = create_and_sign_in_user(%{conn: conn})
      redirect_param = "s12345"

      assert {:error, {:live_redirect, %{to: "/display/static/12345/"}}} =
               live(conn, ~p"/r/#{redirect_param}")
    end

    test "redirects network display pattern", %{conn: conn} do
      redirect_param = "abc"

      assert {:error, {:live_redirect, %{to: "/networks/a/display/single/b/c/"}}} =
               live(conn, ~p"/r/#{redirect_param}")
    end

    test "handles invocation ID with multiple characters", %{conn: conn} do
      redirect_param = "sabcdef123"

      assert {:error, {:live_redirect, %{to: "/display/static/abcdef123/"}}} =
               live(conn, ~p"/r/#{redirect_param}")
    end
  end
end
