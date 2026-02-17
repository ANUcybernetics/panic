defmodule PanicWeb.UserLiveTest do
  @moduledoc """
  Test the user dashboard
  """
  use PanicWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  alias Panic.Watcher.Installation

  describe "user IS logged in" do
    setup do
      PanicWeb.Helpers.stop_all_network_runners()
      :ok
    end

    setup {PanicWeb.Helpers, :create_and_sign_in_user}

    test "and can visit the user index page", %{conn: conn, user: user} do
      conn
      |> visit("/users")
      |> assert_has("#current-user-email", text: Ash.CiString.value(user.email))
      |> assert_has("#users", text: Ash.CiString.value(user.email))
    end

    test "and can visit the user index page and click on their own name", %{
      conn: conn,
      user: user
    } do
      conn
      |> visit("/users")
      |> click_link("#users-#{user.id} > td:nth-child(1)", Integer.to_string(user.id))
    end

    test "and can visit their user page and manage API tokens", %{
      conn: conn,
      user: user
    } do
      token_name = "My Test Tokens"
      token_value = ";laskdfjhnlkjlkj"

      conn
      |> visit("/users/#{user.id}")
      |> click_link("Manage API Tokens")
      |> click_link("New Token Set")
      |> fill_in("Name", with: token_name)
      |> fill_in("Replicate API Token", with: token_value)
      |> submit()
      |> assert_has("h1", text: "API Tokens")
      |> assert_has("#api_tokens", text: token_name)
    end

    test "and can visit their user page and create a network", %{
      conn: conn,
      user: user
    } do
      network_name = "My sweet network."
      network_description = "Isn't it awesome?"

      conn
      |> visit("/users/#{user.id}")
      |> click_link("Add network")
      |> fill_in("Name", with: network_name)
      |> fill_in("Description", with: network_description)
      |> submit()
      |> assert_has("#network-list", text: network_name)
      |> assert_has("#network-list", text: network_description)
    end

    test "and can delete a network from their user page", %{
      conn: conn,
      user: user
    } do
      network = Panic.Fixtures.network_with_dummy_models(user)

      {:ok, view, _html} = live(conn, ~p"/users/#{user.id}")
      assert render(view) =~ network.name

      render_click(view, "delete_network", %{"id" => network.id})
      refute render(view) =~ network.name
    end

    test "network delete with related data shows proper error", %{
      conn: conn,
      user: user
    } do
      network = Panic.Fixtures.network_with_dummy_models(user)

      installation =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{network_id: network.id, name: "Test Installation", watchers: []},
          actor: user
        )
        |> Ash.create!()

      {:ok, view, _html} = live(conn, ~p"/users/#{user.id}")
      assert render(view) =~ network.name

      render_click(view, "delete_network", %{"id" => network.id})
      refute render(view) =~ network.name

      assert {:error, _} = Ash.get(Panic.Engine.Network, network.id, actor: user)
      assert {:error, _} = Ash.get(Installation, installation.id, actor: user)
    end
  end

  describe "user is NOT logged in" do
    test "and there's no email in the top-right", %{conn: conn} do
      conn
      |> visit("/")
      |> refute_has("#current-user-email")
    end
  end
end
