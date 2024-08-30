defmodule PanicWeb.UserLiveTest do
  @moduledoc """
  Test the user dashboard

  Code modified from https://elixirforum.com/t/how-to-test-live-views-with-ash-authentication-plugs/59814/

  Thanks @peterhartman and @brunoripa
  """
  use PanicWeb.ConnCase, async: true
  # import Phoenix.LiveViewTest

  describe "user IS logged in" do
    setup {PanicWeb.Helpers, :create_and_sign_in_user}

    test "and their email shows in the top-right", %{conn: conn, user: user} do
      conn
      |> visit("/")
      |> assert_has("#current-user-email", text: user.email |> Ash.CiString.value())
    end

    test "and can visit the user index page", %{conn: conn, user: user} do
      conn
      |> visit("/users")
      |> assert_has("#current-user-email", text: user.email |> Ash.CiString.value())
      |> assert_has("#users", text: user.email |> Ash.CiString.value())
    end

    test "and can visit the user index page and click on their own name", %{
      conn: conn,
      user: user
    } do
      conn
      |> visit("/users")
      |> click_link("#users-#{user.id} > td:nth-child(1)", Integer.to_string(user.id))
    end

    test "and can visit the user index page and add an API token", %{
      conn: conn,
      user: user
    } do
      token_value = ";laskdfjhnlkjlkj"

      conn
      |> visit("/users")
      |> click_link("#users-#{user.id} > td:nth-child(1)", Integer.to_string(user.id))
      |> click_link("Edit user")
      |> fill_in("Replicate API Token", with: token_value)
      |> submit()
      |> assert_has("#token-list", text: token_value)
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
