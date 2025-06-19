defmodule PanicWeb.UserLiveTest do
  @moduledoc """
  Test the user dashboard

  Code modified from https://elixirforum.com/t/how-to-test-live-views-with-ash-authentication-plugs/59814/

  Thanks @peterhartman and @brunoripa
  """
  use PanicWeb.ConnCase, async: false
  # import Phoenix.LiveViewTest

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

    test "and can visit their user page and add an API token", %{
      conn: conn,
      user: user
    } do
      token_value = ";laskdfjhnlkjlkj"

      conn
      |> visit("/users/#{user.id}")
      |> click_link("Update API Tokens")
      |> fill_in("Replicate API Token", with: token_value)
      |> submit()
      |> assert_has("#token-list", text: token_value)
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
  end

  describe "user is NOT logged in" do
    test "and there's no email in the top-right", %{conn: conn} do
      conn
      |> visit("/")
      |> refute_has("#current-user-email")
    end
  end
end
