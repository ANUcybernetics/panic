defmodule Panic.WatcherTest do
  @moduledoc """
  Tests for the Watcher embedded schema validations.
  """
  use Panic.DataCase, async: false

  alias Panic.Engine.Installation
  alias Panic.Engine.Network

  setup do
    user = Panic.Fixtures.user()

    network =
      Network
      |> Ash.Changeset.for_create(:create, %{name: "Test Network"}, actor: user)
      |> Ash.create!()

    {:ok, user: user, network: network}
  end

  describe "grid watcher validations" do
    test "accepts valid grid watcher", %{user: user, network: network} do
      assert {:ok, installation} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{type: :grid, rows: 2, columns: 3}]
                 },
                 actor: user
               )
               |> Ash.create()

      assert [watcher] = installation.watchers
      assert watcher.type == :grid
      assert watcher.rows == 2
      assert watcher.columns == 3
    end

    test "rejects grid watcher without rows", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{type: :grid, columns: 3}]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      assert watcher_errors[:rows]
    end

    test "rejects grid watcher without columns", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{type: :grid, rows: 2}]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      assert watcher_errors[:columns]
    end

    test "rejects grid watcher with stride/offset", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{type: :grid, rows: 2, columns: 3, stride: 1}]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      assert watcher_errors[:stride]
    end

    test "rejects grid watcher with negative dimensions", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{type: :grid, rows: -1, columns: 3}]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      assert watcher_errors[:rows]
    end
  end

  describe "single watcher validations" do
    test "accepts valid single watcher", %{user: user, network: network} do
      assert {:ok, installation} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{type: :single, stride: 3, offset: 1}]
                 },
                 actor: user
               )
               |> Ash.create()

      assert [watcher] = installation.watchers
      assert watcher.type == :single
      assert watcher.stride == 3
      assert watcher.offset == 1
    end

    test "accepts single watcher with -1 offset for genesis display", %{user: user, network: network} do
      assert {:ok, installation} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test Genesis Single",
                   network_id: network.id,
                   watchers: [%{type: :single, stride: 3, offset: -1}]
                 },
                 actor: user
               )
               |> Ash.create()

      assert [watcher] = installation.watchers
      assert watcher.type == :single
      assert watcher.stride == 3
      assert watcher.offset == -1
    end

    test "rejects single watcher without stride", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{type: :single, offset: 1}]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      assert watcher_errors[:stride]
    end

    test "rejects single watcher without offset", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{type: :single, stride: 3}]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      assert watcher_errors[:offset]
    end

    test "rejects single watcher with rows/columns", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{type: :single, stride: 3, offset: 1, rows: 2}]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      assert watcher_errors[:rows]
    end

    test "rejects single watcher with offset >= stride", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{type: :single, stride: 2, offset: 2}]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      assert watcher_errors[:offset]
    end

    test "rejects single watcher with zero stride", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{type: :single, stride: 0, offset: 0}]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      assert watcher_errors[:stride]
    end

    test "rejects single watcher with negative offset", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{type: :single, stride: 3, offset: -2}]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      assert watcher_errors[:offset]
    end
  end

  describe "vestaboard watcher validations" do
    test "accepts valid vestaboard watchers", %{user: user, network: network} do
      for name <- [:panic_1, :panic_2, :panic_3, :panic_4] do
        assert {:ok, installation} =
                 Installation
                 |> Ash.Changeset.for_create(
                   :create,
                   %{
                     name: "Test #{name}",
                     network_id: network.id,
                     watchers: [%{type: :vestaboard, stride: 2, offset: 0, name: name}]
                   },
                   actor: user
                 )
                 |> Ash.create()

        assert [watcher] = installation.watchers
        assert watcher.type == :vestaboard
        assert watcher.stride == 2
        assert watcher.offset == 0
        assert watcher.name == name
      end
    end

    test "accepts vestaboard watcher with -1 offset for genesis display", %{user: user, network: network} do
      assert {:ok, installation} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test Genesis",
                   network_id: network.id,
                   watchers: [%{type: :vestaboard, stride: 3, offset: -1, name: :panic_1}]
                 },
                 actor: user
               )
               |> Ash.create()

      assert [watcher] = installation.watchers
      assert watcher.type == :vestaboard
      assert watcher.stride == 3
      assert watcher.offset == -1
      assert watcher.name == :panic_1
    end

    test "rejects vestaboard watcher without name", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{type: :vestaboard, stride: 1, offset: 0}]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      assert watcher_errors[:name]
    end

    test "rejects vestaboard watcher with invalid name", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{type: :vestaboard, stride: 1, offset: 0, name: :invalid_name}]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      assert watcher_errors[:name]
    end

    test "rejects vestaboard watcher without stride/offset", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{type: :vestaboard, name: :panic_1}]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      assert watcher_errors[:stride]
    end

    test "rejects vestaboard watcher with rows/columns", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{type: :vestaboard, stride: 1, offset: 0, name: :panic_1, rows: 2}]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      assert watcher_errors[:rows]
    end

    test "rejects vestaboard watcher with offset >= stride (except -1)", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{type: :vestaboard, stride: 2, offset: 2, name: :panic_1}]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      assert watcher_errors[:offset]
    end
  end

  describe "multiple watchers" do
    test "accepts multiple valid watchers of different types", %{user: user, network: network} do
      assert {:ok, installation} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [
                     %{type: :grid, rows: 2, columns: 3},
                     %{type: :single, stride: 3, offset: 1},
                     %{type: :vestaboard, stride: 1, offset: 0, name: :panic_1}
                   ]
                 },
                 actor: user
               )
               |> Ash.create()

      assert length(installation.watchers) == 3
      assert [grid, single, vestaboard] = installation.watchers
      assert grid.type == :grid
      assert single.type == :single
      assert vestaboard.type == :vestaboard
    end

    test "validates each watcher independently", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [
                     # Valid
                     %{type: :grid, rows: 2, columns: 3},
                     # Invalid: offset >= stride
                     %{type: :single, stride: 2, offset: 2},
                     # Invalid: missing name
                     %{type: :vestaboard, stride: 1, offset: 0}
                   ]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      # Should have errors for both offset and the missing name
      assert watcher_errors[:offset] || watcher_errors[:name]
    end
  end

  describe "watcher type validation" do
    test "rejects invalid watcher type", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{type: :invalid_type}]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      assert watcher_errors[:type]
    end

    test "rejects watcher without type", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{rows: 2, columns: 3}]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      assert watcher_errors[:type]
    end
  end
end
