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

    test "loads and renders markdown file content", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/about")

      # The initial HTML might not have the content, so we need to get the rendered view
      rendered = render(view)

      # Verify the markdown file is loaded and rendered
      # Check for specific content from the about.md file
      assert rendered =~ "PANIC!"
      # Part of "Playground"
      assert rendered =~ "layground"
      # Part of "Interactive"
      assert rendered =~ "nteractive"
      # Part of "Creativity"
      assert rendered =~ "reativity"

      # Verify it's rendered as HTML (markdown converted)
      assert rendered =~ "prose-purple"

      # Check that some of the markdown content is present
      assert rendered =~ "feedback"
      assert rendered =~ "generative AI" || rendered =~ "GenAI"
    end

    test "markdown file exists in priv directory" do
      # This test verifies the file path resolution works correctly
      file_path = Application.app_dir(:panic, "priv/static/md/about.md")

      assert File.exists?(file_path),
             "Expected markdown file to exist at #{file_path}"

      # Verify we can read the file
      assert {:ok, content} = File.read(file_path)
      assert content =~ "PANIC!"
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
