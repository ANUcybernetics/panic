defmodule PanicWeb.APITokenLiveTest do
  use PanicWeb.ConnCase

  import Phoenix.LiveViewTest
  import Panic.NetworksFixtures
  import Panic.AccountsFixtures

  defp random_ascii(count) do
    (Enum.to_list(65..90) ++ Enum.to_list(97..122)) |> Enum.take_random(count)
  end

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

    test "lists all api_tokens", %{conn: conn, api_token: api_token} do
      {:ok, _index_live, html} = live(conn, ~p"/api_tokens")

      assert html =~ "Listing API tokens"
      assert html =~ api_token.name
    end

    test "saves new api_token", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/api_tokens")

      assert index_live |> element("a", "New API token") |> render_click() =~
               "New API token"

      assert_patch(index_live, ~p"/api_tokens/new")

      assert index_live
             |> form("#api_token-form", api_token: %{name: nil, token: nil})
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#api_token-form", api_token: %{name: "some new name", token: "aasdflkjww1234"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/api_tokens")

      assert html =~ "API token created successfully"
      assert html =~ "some new name"
    end

    test "updates api_token in listing", %{conn: conn, api_token: api_token} do
      {:ok, index_live, _html} = live(conn, ~p"/api_tokens")

      assert index_live |> element("#api_tokens-#{api_token.id} a", "Edit") |> render_click() =~
               "Edit API token"

      assert_patch(index_live, ~p"/api_tokens/#{api_token}/edit")

      assert index_live
             |> form("#api_token-form", api_token: %{name: nil, token: nil})
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#api_token-form", api_token: %{name: "new name", token: "new token"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/api_tokens")

      assert html =~ "API token updated successfully"
      assert html =~ "new name"
    end

    test "deletes api_token in listing", %{conn: conn, api_token: api_token} do
      {:ok, index_live, _html} = live(conn, ~p"/api_tokens")

      assert index_live |> element("#api_tokens-#{api_token.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#api_token-#{api_token.id}")
    end

    test "graceful error when attempting to create a duplicate token", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/api_tokens/new")

      assert index_live
             |> form("#api_token-form", api_token: %{name: "token name", token: ";laskdfh"})
             |> render_submit()
             |> follow_redirect(conn, ~p"/api_tokens")

      # try again with the same token name
      {:ok, index_live, _html} = live(conn, ~p"/api_tokens/new")

      assert index_live
             |> form("#api_token-form", api_token: %{name: "token name", token: "1234567890"})
             |> render_change() =~ "an API Token with that name already exists"
    end
  end

  describe "Show" do
    setup [:create_and_log_in_user, :create_network, :create_api_token]

    test "displays api_token", %{conn: conn, api_token: api_token} do
      {:ok, _show_live, html} = live(conn, ~p"/api_tokens/#{api_token}")

      assert html =~ "Show API token"
      assert html =~ api_token.name
    end

    test "updates api_token within modal", %{conn: conn, api_token: api_token} do
      {:ok, show_live, _html} = live(conn, ~p"/api_tokens/#{api_token}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit API token"

      assert_patch(show_live, ~p"/api_tokens/#{api_token}/show/edit")

      assert show_live
             |> form("#api_token-form", api_token: %{name: nil, token: nil})
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        show_live
        |> form("#api_token-form", api_token: %{name: "another name", token: "another token"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/api_tokens/#{api_token}")

      assert html =~ "API token updated successfully"
      assert html =~ "another name"
    end
  end
end
