defmodule PanicWeb.APITokenLiveTest do
  use PanicWeb.ConnCase

  import Phoenix.LiveViewTest
  import Panic.NetworksFixtures
  import Panic.AccountsFixtures

  @create_attrs %{name: "some name", token: "some token"}
  @update_attrs %{name: "some updated name", token: "some updated token"}
  @invalid_attrs %{name: nil, token: nil}

  defp create_and_log_in_user(%{conn: conn} = context) do
    password = "123456789abcd"
    user = user_fixture(%{password: password})

    {:ok, lv, _html} = live(conn, ~p"/users/log_in")

    form =
      form(lv, "#login_form", user: %{email: user.email, password: password, remember_me: true})

    conn = submit_form(form, conn)

    context
    |> Map.put(:user, user)
    |> Map.put(:conn, conn)
  end

  defp create_network(%{user: user} = context) do
    Map.put(context, :network, network_fixture(%{user_id: user.id}))
  end

  defp create_api_token(%{user: user} = context) do
    Map.put(context, :api_token, api_token_fixture(%{user_id: user.id}))
  end

  describe "Index" do
    setup [:create_and_log_in_user, :create_network, :create_api_token]

    test "lists all api_token", %{conn: conn, api_token: api_token} do
      {:ok, _index_live, html} = live(conn, ~p"/api_tokens")

      assert html =~ "Listing Api tokens"
      assert html =~ api_token.name
    end

    test "saves new api_token", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/api_tokens")

      assert index_live |> element("a", "New Api tokens") |> render_click() =~
               "New Api tokens"

      assert_patch(index_live, ~p"/api_tokens/new")

      assert index_live
             |> form("#api_token-form", api_token: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#api_token-form", api_token: @create_attrs)
        |> render_submit()
        |> follow_redirect(conn, ~p"/api_tokens")

      assert html =~ "Api tokens created successfully"
      assert html =~ "some name"
    end

    test "updates api_token in listing", %{conn: conn, api_token: api_token} do
      {:ok, index_live, _html} = live(conn, ~p"/api_tokens")

      assert index_live |> element("#api_token-#{api_token.id} a", "Edit") |> render_click() =~
               "Edit Api tokens"

      assert_patch(index_live, ~p"/api_tokens/#{api_token}/edit")

      assert index_live
             |> form("#api_token-form", api_token: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#api_token-form", api_token: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, ~p"/api_tokens")

      assert html =~ "Api tokens updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes api_token in listing", %{conn: conn, api_token: api_token} do
      {:ok, index_live, _html} = live(conn, ~p"/api_tokens")

      assert index_live |> element("#api_token-#{api_token.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#api_token-#{api_token.id}")
    end
  end

  describe "Show" do
    setup [:create_and_log_in_user, :create_network, :create_api_token]

    test "displays api_token", %{conn: conn, api_token: api_token} do
      {:ok, _show_live, html} = live(conn, ~p"/api_tokens/#{api_token}")

      assert html =~ "Show Api tokens"
      assert html =~ api_token.name
    end

    test "updates api_token within modal", %{conn: conn, api_token: api_token} do
      {:ok, show_live, _html} = live(conn, ~p"/api_tokens/#{api_token}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Api tokens"

      assert_patch(show_live, ~p"/api_tokens/#{api_token}/show/edit")

      assert show_live
             |> form("#api_token-form", api_token: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        show_live
        |> form("#api_token-form", api_token: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, ~p"/api_tokens/#{api_token}")

      assert html =~ "Api tokens updated successfully"
      assert html =~ "some updated name"
    end
  end
end
