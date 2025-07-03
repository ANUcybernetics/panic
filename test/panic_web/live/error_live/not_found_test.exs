defmodule PanicWeb.ErrorLive.NotFoundTest do
  use PanicWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import PanicWeb.Helpers

  describe "404 Not Found page" do
    test "displays 404 page for anonymous users", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/404")
      
      assert has_element?(view, "h1", "404 (page not found)")
      assert has_element?(view, "p", "Whoops - the page you're looking for doesn't exist.")
    end

    test "displays 404 page for authenticated users", %{conn: conn} do
      %{conn: conn} = create_and_sign_in_user(%{conn: conn})
      
      {:ok, view, _html} = live(conn, ~p"/404")
      
      assert has_element?(view, "h1", "404 (page not found)")
      assert has_element?(view, "p", "Whoops - the page you're looking for doesn't exist.")
    end

    test "displays 404 for non-existent routes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/this-route-does-not-exist")
      
      assert has_element?(view, "h1", "404 (page not found)")
      assert has_element?(view, "p", "Whoops - the page you're looking for doesn't exist.")
    end

    test "provides link to about page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/404")
      
      assert has_element?(view, "a[href=\"/about/\"]", "Find out more about PANIC!")
    end

    test "authenticated users see link to about page", %{conn: conn} do
      %{conn: conn} = create_and_sign_in_user(%{conn: conn})
      
      {:ok, view, _html} = live(conn, ~p"/404")
      
      assert has_element?(view, "a[href=\"/about/\"]", "Find out more about PANIC!")
    end
  end
end