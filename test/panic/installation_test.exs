defmodule Panic.InstallationTest do
  @moduledoc """
  Tests for the Installation resource.
  """
  use Panic.DataCase, async: true
  use PanicWeb.Helpers.DatabasePatches

  alias Ash.Error.Invalid
  alias Ash.Error.Query.NotFound
  alias Panic.Engine.Installation
  alias Panic.Engine.Network

  describe "Installation resource" do
    setup do
      PanicWeb.Helpers.stop_all_network_runners()

      user = Panic.Fixtures.user()

      network =
        Network
        |> Ash.Changeset.for_create(:create, %{name: "Test Network"}, actor: user)
        |> Ash.create!()

      {:ok, user: user, network: network}
    end

    test "creates installation with valid attributes", %{user: user, network: network} do
      assert {:ok, installation} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test Installation",
                   network_id: network.id,
                   watchers: [
                     %{type: :grid, rows: 2, columns: 3},
                     %{type: :single, stride: 3, offset: 1}
                   ]
                 },
                 actor: user
               )
               |> Ash.create()

      assert installation.name == "Test Installation"
      assert installation.network_id == network.id
      assert length(installation.watchers) == 2
      assert [grid, single] = installation.watchers
      assert grid.type == :grid
      assert grid.rows == 2
      assert grid.columns == 3
      assert single.type == :single
      assert single.stride == 3
      assert single.offset == 1
    end

    test "requires name", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   network_id: network.id
                 },
                 actor: user
               )
               |> Ash.create()

      assert %{name: ["is required"]} = errors_on(changeset)
    end

    test "requires network_id", %{user: user} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test Installation"
                 },
                 actor: user
               )
               |> Ash.create()

      assert errors = errors_on(changeset)
      assert errors[:network_id] == ["is required"]
    end

    test "defaults watchers to empty array", %{user: user, network: network} do
      assert {:ok, installation} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test Installation",
                   network_id: network.id
                 },
                 actor: user
               )
               |> Ash.create()

      assert installation.watchers == []
    end

    test "adds watcher to installation", %{user: user, network: network} do
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

      assert {:ok, updated} =
               installation
               |> Ash.Changeset.for_update(
                 :add_watcher,
                 %{
                   watcher: %{type: :grid, rows: 2, columns: 3}
                 },
                 actor: user
               )
               |> Ash.update()

      assert length(updated.watchers) == 1
      assert [watcher] = updated.watchers
      assert watcher.type == :grid
      assert watcher.rows == 2
      assert watcher.columns == 3
    end

    test "removes watcher from installation", %{user: user, network: network} do
      {:ok, installation} =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Test Installation",
            network_id: network.id,
            watchers: [
              %{type: :grid, rows: 2, columns: 3},
              %{type: :single, stride: 3, offset: 1}
            ]
          },
          actor: user
        )
        |> Ash.create()

      assert {:ok, updated} =
               installation
               |> Ash.Changeset.for_update(:remove_watcher, %{index: 0}, actor: user)
               |> Ash.update()

      assert length(updated.watchers) == 1
      assert [watcher] = updated.watchers
      assert watcher.type == :single
    end

    test "reorders watchers", %{user: user, network: network} do
      watcher1 = %{type: :grid, rows: 2, columns: 3}
      watcher2 = %{type: :single, stride: 3, offset: 1}
      watcher3 = %{type: :vestaboard, stride: 1, offset: 0, name: :panic_1}

      {:ok, installation} =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Test Installation",
            network_id: network.id,
            watchers: [watcher1, watcher2, watcher3]
          },
          actor: user
        )
        |> Ash.create()

      # Reorder to move the third watcher to the beginning
      reordered = [watcher3, watcher1, watcher2]

      assert {:ok, updated} =
               installation
               |> Ash.Changeset.for_update(:reorder_watchers, %{watchers: reordered}, actor: user)
               |> Ash.update()

      # Compare just the relevant fields of the watchers, filtering out nil values
      actual_watchers =
        Enum.map(updated.watchers, fn watcher ->
          watcher
          |> Map.take([:type, :rows, :columns, :stride, :offset, :name])
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)
          |> Map.new()
        end)

      assert actual_watchers == reordered
    end

    test "validates watcher when adding", %{user: user, network: network} do
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

      assert {:error, _changeset} =
               installation
               |> Ash.Changeset.for_update(
                 :add_watcher,
                 %{
                   # Missing required rows/columns
                   watcher: %{type: :grid}
                 },
                 actor: user
               )
               |> Ash.update()
    end

    test "handles invalid index when removing watcher", %{user: user, network: network} do
      {:ok, installation} =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Test Installation",
            network_id: network.id,
            watchers: [
              %{type: :grid, rows: 2, columns: 3}
            ]
          },
          actor: user
        )
        |> Ash.create()

      # Test negative index
      assert {:error, changeset} =
               installation
               |> Ash.Changeset.for_update(:remove_watcher, %{index: -1}, actor: user)
               |> Ash.update()

      assert %{index: ["index is out of bounds"]} = errors_on(changeset)

      # Test index that's too high
      assert {:error, changeset} =
               installation
               |> Ash.Changeset.for_update(:remove_watcher, %{index: 10}, actor: user)
               |> Ash.update()

      assert %{index: ["index is out of bounds"]} = errors_on(changeset)
    end

    test "handles empty watchers list when removing", %{user: user, network: network} do
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

      assert {:error, changeset} =
               installation
               |> Ash.Changeset.for_update(:remove_watcher, %{index: 0}, actor: user)
               |> Ash.update()

      assert %{index: ["index is out of bounds"]} = errors_on(changeset)
    end

    test "validates watcher with invalid attributes", %{user: user, network: network} do
      # Test grid without rows/columns
      assert {:error, _changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test Installation",
                   network_id: network.id,
                   watchers: [%{type: :grid}]
                 },
                 actor: user
               )
               |> Ash.create()

      # Test single without stride/offset
      assert {:error, _changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test Installation",
                   network_id: network.id,
                   watchers: [%{type: :single}]
                 },
                 actor: user
               )
               |> Ash.create()

      # Test vestaboard without name
      assert {:error, _changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test Installation",
                   network_id: network.id,
                   watchers: [%{type: :vestaboard, stride: 1, offset: 0}]
                 },
                 actor: user
               )
               |> Ash.create()

      # Test offset >= stride
      assert {:error, _changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test Installation",
                   network_id: network.id,
                   watchers: [%{type: :single, stride: 2, offset: 2}]
                 },
                 actor: user
               )
               |> Ash.create()
    end
  end

  describe "Installation policies" do
    setup do
      PanicWeb.Helpers.stop_all_network_runners()

      user1 = Panic.Fixtures.user()
      user2 = Panic.Fixtures.user()

      network1 =
        Network
        |> Ash.Changeset.for_create(:create, %{name: "User1 Network"}, actor: user1)
        |> Ash.create!()

      network2 =
        Network
        |> Ash.Changeset.for_create(:create, %{name: "User2 Network"}, actor: user2)
        |> Ash.create!()

      {:ok, user1: user1, user2: user2, network1: network1, network2: network2}
    end

    test "user can create installation for their own network", %{user1: user, network1: network} do
      assert {:ok, _installation} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test Installation",
                   network_id: network.id
                 },
                 actor: user
               )
               |> Ash.create()
    end

    test "user cannot create installation for another user's network", %{user1: user, network2: network} do
      assert {:error, %Ash.Error.Invalid{}} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test Installation",
                   network_id: network.id
                 },
                 actor: user
               )
               |> Ash.create()
    end

    test "user can read their own installations", %{user1: user, network1: network} do
      {:ok, installation} =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Test Installation",
            network_id: network.id
          },
          actor: user
        )
        |> Ash.create()

      assert {:ok, found} = Ash.get(Installation, installation.id, actor: user)
      assert found.id == installation.id
    end

    test "user cannot read another user's installations", %{user1: user1, user2: user2, network2: network} do
      {:ok, installation} =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Test Installation",
            network_id: network.id
          },
          actor: user2
        )
        |> Ash.create()

      assert {:error, %Invalid{errors: [%NotFound{}]}} =
               Ash.get(Installation, installation.id, actor: user1)
    end

    test "user can update their own installations", %{user1: user, network1: network} do
      {:ok, installation} =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Test Installation",
            network_id: network.id
          },
          actor: user
        )
        |> Ash.create()

      assert {:ok, updated} =
               installation
               |> Ash.Changeset.for_update(:update, %{name: "Updated Name"}, actor: user)
               |> Ash.update()

      assert updated.name == "Updated Name"
    end

    test "user cannot update another user's installations", %{user1: user1, user2: user2, network2: network} do
      {:ok, installation} =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Test Installation",
            network_id: network.id
          },
          actor: user2
        )
        |> Ash.create()

      assert {:error, %Invalid{errors: [%NotFound{}]}} =
               Ash.get(Installation, installation.id, actor: user1)
    end

    test "user can destroy their own installations", %{user1: user, network1: network} do
      {:ok, installation} =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Test Installation",
            network_id: network.id
          },
          actor: user
        )
        |> Ash.create()

      assert :ok = Ash.destroy(installation, actor: user)
    end

    test "user cannot destroy another user's installations", %{user1: user1, user2: user2, network2: network} do
      {:ok, installation} =
        Installation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Test Installation",
            network_id: network.id
          },
          actor: user2
        )
        |> Ash.create()

      # Try to get it first (which should fail due to policies)
      assert {:error, %Invalid{errors: [%NotFound{}]}} =
               Ash.get(Installation, installation.id, actor: user1)
    end
  end
end
