defmodule PanicWeb.NetworkIndexTest do
  @moduledoc """
  Test the networks page, which is home once you're signed in.
  """
  use PanicWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Panic.Watcher.Installation

  describe "user IS logged in" do
    setup {PanicWeb.Helpers, :create_and_sign_in_user}

    test "and sees their email and their networks", %{conn: conn, user: user} do
      network = Panic.Fixtures.network_with_dummy_models(user)

      conn
      |> visit("/networks")
      |> assert_has("#current-user-email", text: Ash.CiString.value(user.email))
      |> assert_has("#networks", text: network.name)
    end

    test "and the old user pages redirect to the networks page", %{conn: conn, user: user} do
      for path <- ["/users", "/users/#{user.id}", "/users/#{user.id}/new-network"] do
        assert conn |> get(path) |> redirected_to() == ~p"/networks"
      end
    end

    test "and can create a network", %{conn: conn} do
      network_name = "My sweet network."

      conn
      |> visit("/networks")
      |> click_link("New network")
      |> fill_in("Name", with: network_name)
      |> fill_in("Description", with: "Isn't it awesome?")
      |> submit()
      |> assert_has("h1", text: network_name)
      |> visit("/networks")
      |> assert_has("#networks", text: network_name)
    end

    test "and can delete a network", %{conn: conn, user: user} do
      network = Panic.Fixtures.network_with_dummy_models(user)

      conn
      |> visit(~p"/networks")
      |> assert_has("#networks", text: network.name)
      |> click_button("Delete")
      |> refute_has("#networks", text: network.name)
    end

    test "network delete with related data removes the installations too", %{
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

      {:ok, view, _html} = live(conn, ~p"/networks")
      render_click(view, "delete", %{"id" => network.id})
      refute render(view) =~ network.name

      assert {:error, _} = Ash.get(Panic.Engine.Network, network.id, actor: user)
      assert {:error, _} = Ash.get(Installation, installation.id, actor: user)
    end
  end

  describe "user is NOT logged in" do
    test "and there's no email in the navbar", %{conn: conn} do
      conn
      |> visit("/about")
      |> refute_has("#current-user-email")
    end
  end
end
