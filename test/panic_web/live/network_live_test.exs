defmodule PanicWeb.NetworkLiveTest do
  use PanicWeb.ConnCase, async: false
  use ExUnitProperties
  # import Phoenix.LiveViewTest

  describe "user IS logged in" do
    setup {PanicWeb.Helpers, :create_and_sign_in_user}

    test "and can create a network which is then listed on user page", %{conn: conn, user: user} do
      conn
      |> visit("/users/#{user.id}")
      |> click_link("Add network")
      |> fill_in("Name", with: "Test network")
      |> fill_in("Description", with: "A network for testing purposes")
      |> submit()
      |> assert_has("#network-list", text: "Test network")
    end

    test "and can visit the terminal for a runnable network", %{conn: conn, user: user} do
      # TODO currently I can't get PhoenixTest to fill out the LiveSelect yet, so fake it for now
      network = user |> Panic.Generators.network_with_dummy_models() |> pick()

      visit(conn, "/networks/#{network.id}/terminal")
    end
  end
end
