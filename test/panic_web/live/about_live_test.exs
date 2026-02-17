defmodule PanicWeb.AboutLiveTest do
  use PanicWeb.ConnCase, async: true

  import PanicWeb.Helpers

  describe "About page" do
    test "displays about page for anonymous users", %{conn: conn} do
      conn
      |> visit(~p"/about")
      |> assert_has("div.prose", text: "PANIC!")
    end

    test "displays about page for authenticated users", %{conn: conn} do
      %{conn: conn} = create_and_sign_in_user(%{conn: conn})

      conn
      |> visit(~p"/about")
      |> assert_has("div.prose", text: "PANIC!")
    end

    test "renders about page content", %{conn: conn} do
      conn
      |> visit(~p"/about")
      |> assert_has("div.prose-purple")
      |> assert_has("div.prose", text: "feedback")
      |> assert_has("div.prose", text: "Techy stuff")
      |> assert_has("div.prose", text: "Research Questions")
      |> assert_has("div.prose", text: "Contact")
    end

    test "can navigate to about page from home", %{conn: conn} do
      conn
      |> visit("/")
      |> click_link("About")
      |> assert_has("div.prose")
    end

    test "authenticated users can navigate to about page", %{conn: conn} do
      %{conn: conn} = create_and_sign_in_user(%{conn: conn})

      conn
      |> visit("/")
      |> click_link("About")
      |> assert_has("div.prose")
    end
  end
end
