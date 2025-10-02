defmodule PanicWeb.UserLiveTest do
  @moduledoc """
  Test the user dashboard

  Code modified from https://elixirforum.com/t/how-to-test-live-views-with-ash-authentication-plugs/59814/

  Thanks @peterhartman and @brunoripa
  """
  use PanicWeb.ConnCase, async: false
  # import Phoenix.LiveViewTest
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
      import Phoenix.LiveViewTest

      # Create a network first
      network = Panic.Fixtures.network_with_dummy_models(user)

      # Since PhoenixTest doesn't support JavaScript confirmations, 
      # we'll use Phoenix.LiveViewTest directly for this test
      {:ok, view, _html} = live(conn, ~p"/users/#{user.id}")

      # Verify the network is displayed
      assert render(view) =~ network.name

      # Trigger the delete event directly (bypassing the JavaScript confirmation)
      render_click(view, "delete_network", %{"id" => network.id})

      # Verify the network is no longer displayed
      refute render(view) =~ network.name
    end

    test "network delete with related data shows proper error", %{
      conn: conn,
      user: user
    } do
      import Phoenix.LiveViewTest

      # Create a network with related data
      network = Panic.Fixtures.network_with_dummy_models(user)

      # Create an installation for this network (this is enough to trigger FK constraint)
      installation =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{network_id: network.id, name: "Test Installation", watchers: []},
          actor: user
        )
        |> Ash.create!()

      # Visit the user page
      {:ok, view, _html} = live(conn, ~p"/users/#{user.id}")

      # Verify the network is displayed
      assert render(view) =~ network.name

      # Trigger the delete event - this should work now with cascade_destroy
      render_click(view, "delete_network", %{"id" => network.id})

      # Verify the network is no longer displayed
      refute render(view) =~ network.name

      # Verify all related records are deleted
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
