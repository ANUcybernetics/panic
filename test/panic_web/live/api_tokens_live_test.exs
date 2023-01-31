defmodule PanicWeb.APITokensLiveTest do
  use PanicWeb.ConnCase

  import Phoenix.LiveViewTest
  import Panic.AccountsFixtures

  @create_attrs %{name: "some name", token: "some token"}
  @update_attrs %{name: "some updated name", token: "some updated token"}
  @invalid_attrs %{name: nil, token: nil}

  defp create_api_tokens(_) do
    api_tokens = api_tokens_fixture()
    %{api_tokens: api_tokens}
  end

  describe "Index" do
    setup [:create_api_tokens]

    test "lists all api_tokens", %{conn: conn, api_tokens: api_tokens} do
      {:ok, _index_live, html} = live(conn, ~p"/api_tokens")

      assert html =~ "Listing Api tokens"
      assert html =~ api_tokens.name
    end

    test "saves new api_tokens", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/api_tokens")

      assert index_live |> element("a", "New Api tokens") |> render_click() =~
               "New Api tokens"

      assert_patch(index_live, ~p"/api_tokens/new")

      assert index_live
             |> form("#api_tokens-form", api_tokens: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#api_tokens-form", api_tokens: @create_attrs)
        |> render_submit()
        |> follow_redirect(conn, ~p"/api_tokens")

      assert html =~ "Api tokens created successfully"
      assert html =~ "some name"
    end

    test "updates api_tokens in listing", %{conn: conn, api_tokens: api_tokens} do
      {:ok, index_live, _html} = live(conn, ~p"/api_tokens")

      assert index_live |> element("#api_tokens-#{api_tokens.id} a", "Edit") |> render_click() =~
               "Edit Api tokens"

      assert_patch(index_live, ~p"/api_tokens/#{api_tokens}/edit")

      assert index_live
             |> form("#api_tokens-form", api_tokens: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#api_tokens-form", api_tokens: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, ~p"/api_tokens")

      assert html =~ "Api tokens updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes api_tokens in listing", %{conn: conn, api_tokens: api_tokens} do
      {:ok, index_live, _html} = live(conn, ~p"/api_tokens")

      assert index_live |> element("#api_tokens-#{api_tokens.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#api_tokens-#{api_tokens.id}")
    end
  end

  describe "Show" do
    setup [:create_api_tokens]

    test "displays api_tokens", %{conn: conn, api_tokens: api_tokens} do
      {:ok, _show_live, html} = live(conn, ~p"/api_tokens/#{api_tokens}")

      assert html =~ "Show Api tokens"
      assert html =~ api_tokens.name
    end

    test "updates api_tokens within modal", %{conn: conn, api_tokens: api_tokens} do
      {:ok, show_live, _html} = live(conn, ~p"/api_tokens/#{api_tokens}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Api tokens"

      assert_patch(show_live, ~p"/api_tokens/#{api_tokens}/show/edit")

      assert show_live
             |> form("#api_tokens-form", api_tokens: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        show_live
        |> form("#api_tokens-form", api_tokens: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, ~p"/api_tokens/#{api_tokens}")

      assert html =~ "Api tokens updated successfully"
      assert html =~ "some updated name"
    end
  end
end
