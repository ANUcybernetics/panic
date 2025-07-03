defmodule PanicWeb.AboutLiveTest do
  use PanicWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import PanicWeb.Helpers

  describe "About page" do
    test "displays about page for anonymous users", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")
      
      # The about page displays markdown content, so just check it renders
      assert html =~ "About PANIC!"
    end

    test "displays about page for authenticated users", %{conn: conn} do
      %{conn: conn} = create_and_sign_in_user(%{conn: conn})
      
      {:ok, _view, html} = live(conn, ~p"/about")
      
      # The about page displays markdown content
      assert html =~ "About PANIC!"
    end

    test "can navigate to about page from home using PhoenixTest", %{conn: conn} do
      conn
      |> visit("/")
      |> click_link("About")
      |> assert_has("div.prose")
    end

    test "authenticated users can navigate to about page using PhoenixTest", %{conn: conn} do
      %{conn: conn} = create_and_sign_in_user(%{conn: conn})
      
      conn
      |> visit("/")
      |> click_link("About")
      |> assert_has("div.prose")
    end
  end
end