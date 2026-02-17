defmodule PanicWeb.ErrorLive.NotFoundTest do
  use PanicWeb.ConnCase, async: false

  import PanicWeb.Helpers

  describe "404 Not Found page" do
    test "displays 404 page for anonymous users", %{conn: conn} do
      conn
      |> visit(~p"/404")
      |> assert_has("h1", text: "404 (page not found)")
      |> assert_has("p", text: "Whoops - the page you're looking for doesn't exist.")
    end

    test "displays 404 page for authenticated users", %{conn: conn} do
      %{conn: conn} = create_and_sign_in_user(%{conn: conn})

      conn
      |> visit(~p"/404")
      |> assert_has("h1", text: "404 (page not found)")
      |> assert_has("p", text: "Whoops - the page you're looking for doesn't exist.")
    end

    test "displays 404 for non-existent routes", %{conn: conn} do
      conn
      |> visit(~p"/this-route-does-not-exist")
      |> assert_has("h1", text: "404 (page not found)")
      |> assert_has("p", text: "Whoops - the page you're looking for doesn't exist.")
    end

    test "provides link to about page", %{conn: conn} do
      conn
      |> visit(~p"/404")
      |> assert_has("a[href=\"/about/\"]", text: "Find out more about PANIC!")
    end

    test "authenticated users see link to about page", %{conn: conn} do
      %{conn: conn} = create_and_sign_in_user(%{conn: conn})

      conn
      |> visit(~p"/404")
      |> assert_has("a[href=\"/about/\"]", text: "Find out more about PANIC!")
    end
  end
end
