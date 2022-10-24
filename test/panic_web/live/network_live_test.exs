defmodule PanicWeb.NetworkLiveTest do
  use PanicWeb.ConnCase

  import Phoenix.LiveViewTest
  import Panic.NetworksFixtures

  @create_attrs %{loop: true, models: [], name: "some name"}
  @update_attrs %{loop: false, models: [], name: "some updated name"}
  @invalid_attrs %{loop: false, models: [], name: nil}

  defp create_network(_) do
    network = network_fixture()
    %{network: network}
  end

  describe "Index" do
    setup [:create_network]

    test "lists all networks", %{conn: conn, network: network} do
      {:ok, _index_live, html} = live(conn, Routes.network_index_path(conn, :index))

      assert html =~ "Listing Networks"
      assert html =~ network.name
    end

    test "saves new network", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, Routes.network_index_path(conn, :index))

      assert index_live |> element("a", "New Network") |> render_click() =~
               "New Network"

      assert_patch(index_live, Routes.network_index_path(conn, :new))

      assert index_live
             |> form("#network-form", network: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#network-form", network: @create_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.network_index_path(conn, :index))

      assert html =~ "Network created successfully"
      assert html =~ "some name"
    end

    test "updates network in listing", %{conn: conn, network: network} do
      {:ok, index_live, _html} = live(conn, Routes.network_index_path(conn, :index))

      assert index_live |> element("#network-#{network.id} a", "Edit") |> render_click() =~
               "Edit Network"

      assert_patch(index_live, Routes.network_index_path(conn, :edit, network))

      assert index_live
             |> form("#network-form", network: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#network-form", network: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.network_index_path(conn, :index))

      assert html =~ "Network updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes network in listing", %{conn: conn, network: network} do
      {:ok, index_live, _html} = live(conn, Routes.network_index_path(conn, :index))

      assert index_live |> element("#network-#{network.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#network-#{network.id}")
    end
  end

  describe "Show" do
    setup [:create_network]

    test "displays network", %{conn: conn, network: network} do
      {:ok, _show_live, html} = live(conn, Routes.network_show_path(conn, :show, network))

      assert html =~ "Show Network"
      assert html =~ network.name
    end

    test "updates network within modal", %{conn: conn, network: network} do
      {:ok, show_live, _html} = live(conn, Routes.network_show_path(conn, :show, network))

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Network"

      assert_patch(show_live, Routes.network_show_path(conn, :edit, network))

      assert show_live
             |> form("#network-form", network: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        show_live
        |> form("#network-form", network: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.network_show_path(conn, :show, network))

      assert html =~ "Network updated successfully"
      assert html =~ "some updated name"
    end
  end
end
