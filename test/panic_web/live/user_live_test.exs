defmodule PanicWeb.UserDashboardLiveTest do
  @moduledoc """
  Test the user dashboard

  Code modified from https://elixirforum.com/t/how-to-test-live-views-with-ash-authentication-plugs/59814/

  Thanks @peterhartman and @brunoripa
  """
  use PanicWeb.ConnCase, async: true
  # import Phoenix.LiveViewTest

  describe "user IS logged in" do
    setup [:create_and_sign_in_user]

    test "and their email shows in the top-right", %{conn: conn, user: user} do
      conn
      |> visit("/")
      |> assert_has("#current-user-email", text: user.email |> Ash.CiString.value())

      # open_browser(view)
    end
  end

  describe "user is NOT logged in" do
    test "and there's no email in the top-right", %{conn: conn} do
      conn
      |> visit("/")
      |> refute_has("#current-user-email")
    end
  end

  defp create_and_sign_in_user(%{conn: conn}) do
    password = "abcd1234"
    user = Panic.Fixtures.user(password)
    strategy = AshAuthentication.Info.strategy!(Panic.Accounts.User, :password)

    assert {:ok, user} =
             AshAuthentication.Strategy.action(strategy, :sign_in, %{
               email: user.email,
               password: password
             })

    %{
      conn:
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(user),
      user: user
    }
  end
end
