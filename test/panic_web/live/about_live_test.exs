defmodule PanicWeb.AboutLiveTest do
  use PanicWeb.ConnCase, async: true

  import PanicWeb.Helpers
  import Phoenix.LiveViewTest

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

    test "renders about page content", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify the content is rendered in the initial HTML
      assert html =~ "PANIC!"
      # Part of "Playground"
      assert html =~ "layground"
      # Part of "Interactive"
      assert html =~ "nteractive"
      # Part of "Creativity"
      assert html =~ "reativity"

      # Verify it's rendered as HTML
      assert html =~ "prose-purple"

      # Check that some of the content is present
      assert html =~ "feedback"
      assert html =~ "generative AI" || html =~ "GenAI"

      # Check for specific sections
      assert html =~ "Techy stuff"
      assert html =~ "Research Questions"
      assert html =~ "Contact"
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
