defmodule PanicWeb.InstallationLiveTest do
  @moduledoc """
  Test the installation management pages
  """
  use PanicWeb.ConnCase, async: false

  alias Panic.Engine.Installation
  alias Panic.Engine.Network

  describe "user IS logged in" do
    setup do
      PanicWeb.Helpers.stop_all_network_runners()
      :ok
    end

    setup {PanicWeb.Helpers, :create_and_sign_in_user}

    test "can visit the installation index page", %{conn: conn} do
      conn
      |> visit("/installations")
      |> assert_has("h1", text: "Installations")
      |> assert_has("a", text: "New Installation")
    end

    test "can create a new installation", %{conn: conn, user: user} do
      # Create a network first
      {:ok, _network} =
        Network
        |> Ash.Changeset.for_create(:create, %{name: "Test Network"}, actor: user)
        |> Ash.create()

      conn
      |> visit("/installations")
      |> click_link("New Installation")
      |> fill_in("Name", with: "My Test Installation")
      |> select("Network", option: "Test Network")
      |> submit()
      |> assert_has("td", text: "My Test Installation")
      |> assert_has("td", text: "Test Network")
    end

    test "can add a grid watcher to an installation", %{conn: conn, user: user} do
      # Create network and installation
      {:ok, network} =
        Network
        |> Ash.Changeset.for_create(:create, %{name: "Test Network"}, actor: user)
        |> Ash.create()

      {:ok, installation} =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Test Installation",
            network_id: network.id,
            watchers: []
          },
          actor: user
        )
        |> Ash.create()

      conn
      |> visit("/installations/#{installation.id}")
      |> click_link("Add watcher")
      |> select("Type", option: "Grid - Display invocations in a grid layout")
      |> fill_in("Name", with: "main-grid")
      |> fill_in("Rows", with: "2")
      |> fill_in("Columns", with: "3")
      |> submit()
      |> assert_has("h3", text: "main-grid (grid)")
      |> assert_has("dt", text: "Type")
      |> assert_has("dd", text: "grid")
      |> assert_has("dt", text: "Dimensions")
      |> assert_has("dd", text: "2 × 3")
    end

    test "can add a single watcher to an installation", %{conn: conn, user: user} do
      # Create network and installation
      {:ok, network} =
        Network
        |> Ash.Changeset.for_create(:create, %{name: "Test Network"}, actor: user)
        |> Ash.create()

      {:ok, installation} =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Test Installation",
            network_id: network.id,
            watchers: []
          },
          actor: user
        )
        |> Ash.create()

      conn
      |> visit("/installations/#{installation.id}")
      |> click_link("Add watcher")
      |> select("Type", option: "Single - Show one invocation at a time")
      |> fill_in("Name", with: "spotlight")
      |> fill_in("Stride", with: "3")
      |> fill_in("Offset", with: "1")
      |> submit()
      |> assert_has("h3", text: "spotlight (single)")
      |> assert_has("dt", text: "Type")
      |> assert_has("dd", text: "single")
      |> assert_has("dt", text: "Stride")
      |> assert_has("dd", text: "3")
      |> assert_has("dt", text: "Offset")
      |> assert_has("dd", text: "1")
    end

    test "can add a single watcher with show_invoking enabled", %{conn: conn, user: user} do
      # Create network and installation
      {:ok, network} =
        Network
        |> Ash.Changeset.for_create(:create, %{name: "Test Network"}, actor: user)
        |> Ash.create()

      {:ok, installation} =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Test Installation",
            network_id: network.id,
            watchers: []
          },
          actor: user
        )
        |> Ash.create()

      conn
      |> visit("/installations/#{installation.id}")
      |> click_link("Add watcher")
      |> select("Type", option: "Single - Show one invocation at a time")
      |> fill_in("Name", with: "live-view")
      |> fill_in("Stride", with: "2")
      |> fill_in("Offset", with: "0")
      |> check("Show Invoking State")
      |> submit()
      |> assert_has("h3", text: "live-view (single)")
      |> assert_has("dt", text: "Show Invoking")
      |> assert_has("dd", text: "Yes")

      # Verify the watcher was created with show_invoking: true
      updated_installation = Ash.reload!(installation, actor: user)
      [watcher] = updated_installation.watchers
      assert watcher.show_invoking == true
    end

    test "grid watcher form does not show show_invoking checkbox", %{conn: conn, user: user} do
      # Create network and installation
      {:ok, network} =
        Network
        |> Ash.Changeset.for_create(:create, %{name: "Test Network"}, actor: user)
        |> Ash.create()

      {:ok, installation} =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Test Installation",
            network_id: network.id,
            watchers: []
          },
          actor: user
        )
        |> Ash.create()

      conn
      |> visit("/installations/#{installation.id}")
      |> click_link("Add watcher")
      |> select("Type", option: "Grid - Display invocations in a grid layout")
      |> refute_has("input[name='form[watcher][show_invoking]']")
      |> fill_in("Name", with: "test-grid")
      |> fill_in("Rows", with: "2")
      |> fill_in("Columns", with: "3")
      |> submit()
      |> assert_has("h3", text: "test-grid (grid)")
    end

    test "can add a vestaboard watcher to an installation", %{conn: conn, user: user} do
      # Create network and installation
      {:ok, network} =
        Network
        |> Ash.Changeset.for_create(:create, %{name: "Test Network"}, actor: user)
        |> Ash.create()

      {:ok, installation} =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Test Installation",
            network_id: network.id,
            watchers: []
          },
          actor: user
        )
        |> Ash.create()

      conn
      |> visit("/installations/#{installation.id}")
      |> click_link("Add watcher")
      |> select("Type", option: "Vestaboard - Display for Vestaboard device")
      |> fill_in("Name", with: "board-1")
      |> fill_in("Stride", with: "2")
      |> fill_in("Offset", with: "0")
      |> select("Vestaboard Name", option: "Panic 1")
      |> submit()
      |> assert_has("h3", text: "board-1 (vestaboard)")
      |> assert_has("dt", text: "Type")
      |> assert_has("dd", text: "vestaboard")
      |> assert_has("dt", text: "Vestaboard Name")
      |> assert_has("dd", text: "panic_1")
    end

    test "can remove a watcher from an installation", %{conn: conn, user: user} do
      # Create network and installation with a watcher
      {:ok, network} =
        Network
        |> Ash.Changeset.for_create(:create, %{name: "Test Network"}, actor: user)
        |> Ash.create()

      {:ok, installation} =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Test Installation",
            network_id: network.id,
            watchers: [%{type: :grid, name: "delete-test", rows: 2, columns: 3}]
          },
          actor: user
        )
        |> Ash.create()

      conn
      |> visit("/installations/#{installation.id}")
      |> assert_has("h3", text: "delete-test (grid)")
      |> click_link("Delete")
      |> assert_has("div", text: "No watchers configured")
    end

    test "can edit an installation", %{conn: conn, user: user} do
      # Create network and installation
      {:ok, network} =
        Network
        |> Ash.Changeset.for_create(:create, %{name: "Test Network"}, actor: user)
        |> Ash.create()

      {:ok, installation} =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Test Installation",
            network_id: network.id,
            watchers: []
          },
          actor: user
        )
        |> Ash.create()

      conn
      |> visit("/installations/#{installation.id}")
      |> click_link("Edit installation")
      |> fill_in("Name", with: "Updated Installation")
      |> submit()
      |> assert_has("h1", text: "Updated Installation")
    end

    test "can view a watcher display", %{conn: conn, user: user} do
      # Create network and installation with a grid watcher
      {:ok, network} =
        Network
        |> Ash.Changeset.for_create(:create, %{name: "Test Network"}, actor: user)
        |> Ash.create()

      {:ok, installation} =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Test Installation",
            network_id: network.id,
            watchers: [%{type: :grid, name: "display-grid", rows: 2, columns: 3}]
          },
          actor: user
        )
        |> Ash.create()

      conn
      |> visit("/installations/#{installation.id}")
      |> click_link("View watcher at /i/#{installation.id}/display-grid →")
      |> assert_has("title", text: "Test Installation - display-grid")
    end

    test "watcher display can be viewed", %{conn: conn, user: user} do
      # Create network and installation with a single watcher
      {:ok, network} =
        Network
        |> Ash.Changeset.for_create(:create, %{name: "Test Network"}, actor: user)
        |> Ash.create()

      {:ok, installation} =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Test Installation",
            network_id: network.id,
            watchers: [%{type: :single, name: "single-display", stride: 1, offset: 0}]
          },
          actor: user
        )
        |> Ash.create()

      # Visit the watcher display page and verify it loads correctly
      conn
      |> visit("/i/#{installation.id}/single-display")
      |> assert_has("title", text: "Test Installation - single-display")
    end

    test "can delete an installation", %{conn: conn, user: user} do
      # Create network and installation
      {:ok, network} =
        Network
        |> Ash.Changeset.for_create(:create, %{name: "Test Network"}, actor: user)
        |> Ash.create()

      {:ok, _installation} =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Test Installation",
            network_id: network.id,
            watchers: []
          },
          actor: user
        )
        |> Ash.create()

      conn
      |> visit("/installations")
      |> assert_has("td", text: "Test Installation")
      |> click_link("Delete")
      |> refute_has("td", text: "Test Installation")
    end
  end

  describe "user is NOT logged in" do
    test "can view an installation watcher display", %{conn: conn} do
      # Create a user, network, and installation
      user = Panic.Fixtures.user()

      {:ok, network} =
        Network
        |> Ash.Changeset.for_create(:create, %{name: "Test Network"}, actor: user)
        |> Ash.create()

      {:ok, installation} =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Test Installation",
            network_id: network.id,
            watchers: [%{type: :grid, name: "public-grid", rows: 2, columns: 3}]
          },
          actor: user
        )
        |> Ash.create()

      conn
      |> visit("/i/#{installation.id}/public-grid")
      |> assert_has("title", text: "Test Installation - public-grid")
    end

    test "cannot access installation management pages", %{conn: conn} do
      conn
      |> visit("/installations")
      |> assert_path("/sign-in")
    end
  end
end
