defmodule PanicWeb.NetworkLiveTest do
  use PanicWeb.ConnCase

  import Phoenix.LiveViewTest
  import Panic.NetworksFixtures
  import Panic.AccountsFixtures

  @create_attrs %{
    description: "some description",
    name: "some name"
  }
  @update_attrs %{
    description: "some updated description",
    name: "some updated name"
  }
  @invalid_attrs %{description: nil, name: nil}

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

  describe "Index" do
    setup [:create_and_log_in_user, :create_network]

    test "lists all networks", %{conn: conn, network: network} do
      {:ok, _index_live, html} = live(conn, ~p"/networks")

      assert html =~ "Listing Networks"
      assert html =~ network.description
    end

    test "saves new network", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/networks")

      assert index_live |> element("a", "New Network") |> render_click() =~
               "New Network"

      assert_patch(index_live, ~p"/networks/new")

      assert index_live
             |> form("#network-form", network: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#network-form", network: @create_attrs)
        |> render_submit()
        |> follow_redirect(conn, ~p"/networks")

      assert html =~ "Network created successfully"
      assert html =~ "some description"
    end

    test "updates network in listing", %{conn: conn, network: network} do
      {:ok, index_live, _html} = live(conn, ~p"/networks")

      assert index_live |> element("#networks-#{network.id} a", "Edit") |> render_click() =~
               "Edit Network"

      assert_patch(index_live, ~p"/networks/#{network}/edit")

      assert index_live
             |> form("#network-form", network: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#network-form", network: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, ~p"/networks")

      assert html =~ "Network updated successfully"
      assert html =~ "some updated description"
    end

    test "deletes network in listing", %{conn: conn, network: network} do
      {:ok, index_live, _html} = live(conn, ~p"/networks")

      assert index_live |> element("#networks-#{network.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#network-#{network.id}")
    end
  end

  describe "Show" do
    setup [:create_and_log_in_user, :create_network]

    test "displays network", %{conn: conn, network: network} do
      {:ok, _show_live, html} = live(conn, ~p"/networks/#{network}")

      assert html =~ "Show Network"
      assert html =~ network.description
    end

    test "updates network within modal", %{conn: conn, network: network} do
      {:ok, show_live, _html} = live(conn, ~p"/networks/#{network}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Network"

      assert_patch(show_live, ~p"/networks/#{network}/show/edit")

      assert show_live
             |> form("#network-form", network: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        show_live
        |> form("#network-form", network: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, ~p"/networks/#{network}")

      assert html =~ "Network updated successfully"
      assert html =~ "some updated description"
    end
  end
end
