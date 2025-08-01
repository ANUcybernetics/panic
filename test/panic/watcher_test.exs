defmodule Panic.WatcherTest do
  @moduledoc """
  Tests for the Watcher embedded schema validations.
  """
  use Panic.DataCase, async: false

  alias Ash.Error.Invalid
  alias Panic.Engine.Network
  alias Panic.Watcher.Installation

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
                   watchers: [%{type: :grid, name: "test-grid", rows: 2, columns: 3}]
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
                   watchers: [%{type: :grid, name: "missing-rows", columns: 3}]
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
                   watchers: [%{type: :grid, name: "missing-columns", rows: 2}]
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
                   watchers: [%{type: :grid, name: "grid-with-stride", rows: 2, columns: 3, stride: 1}]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      assert watcher_errors[:stride]
    end

    test "rejects grid watcher with negative dimensions", %{user: user, network: network} do
      assert {:error, %Invalid{}} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{type: :grid, name: "negative-dimensions", rows: -1, columns: 2}]
                 },
                 actor: user
               )
               |> Ash.create()
    end

    test "rejects grid watcher with show_invoking", %{user: user, network: network} do
      assert {:error, %Invalid{}} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{type: :grid, name: "grid-with-show-invoking", rows: 2, columns: 3, show_invoking: true}]
                 },
                 actor: user
               )
               |> Ash.create()
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
                   watchers: [%{type: :single, name: "test-single", stride: 3, offset: 1}]
                 },
                 actor: user
               )
               |> Ash.create()

      assert [watcher] = installation.watchers
      assert watcher.type == :single
      assert watcher.stride == 3
      assert watcher.offset == 1
    end

    test "accepts single watcher with valid offset", %{user: user, network: network} do
      assert {:ok, installation} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test Genesis Single",
                   network_id: network.id,
                   watchers: [%{type: :single, name: "genesis-single", stride: 3, offset: 0}]
                 },
                 actor: user
               )
               |> Ash.create()

      assert [watcher] = installation.watchers
      assert watcher.type == :single
      assert watcher.stride == 3
      assert watcher.offset == 0
    end

    test "accepts single watcher with show_invoking true", %{user: user, network: network} do
      assert {:ok, installation} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test Single Show Invoking",
                   network_id: network.id,
                   watchers: [%{type: :single, name: "single-show-invoking", stride: 2, offset: 1, show_invoking: true}]
                 },
                 actor: user
               )
               |> Ash.create()

      assert [watcher] = installation.watchers
      assert watcher.type == :single
      assert watcher.stride == 2
      assert watcher.offset == 1
      assert watcher.show_invoking == true
    end

    test "accepts single watcher with show_invoking false", %{user: user, network: network} do
      assert {:ok, installation} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test Single No Invoking",
                   network_id: network.id,
                   watchers: [%{type: :single, name: "single-no-invoking", stride: 1, offset: 0, show_invoking: false}]
                 },
                 actor: user
               )
               |> Ash.create()

      assert [watcher] = installation.watchers
      assert watcher.type == :single
      assert watcher.stride == 1
      assert watcher.offset == 0
      assert watcher.show_invoking == false
    end

    test "rejects single watcher without stride", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{type: :single, name: "missing-stride", offset: 1}]
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
                   watchers: [%{type: :single, name: "missing-offset", stride: 3}]
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
                   watchers: [%{type: :single, name: "single-with-rows", stride: 3, offset: 1, rows: 2}]
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
                   watchers: [%{type: :single, name: "invalid-offset", stride: 2, offset: 2}]
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
                   watchers: [%{type: :single, name: "zero-stride", stride: 0, offset: 0}]
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
                   watchers: [%{type: :single, name: "negative-offset", stride: 1, offset: -1}]
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
                     watchers: [
                       %{
                         type: :vestaboard,
                         name: "test-board-#{name |> Atom.to_string() |> String.replace("_", "-")}",
                         stride: 2,
                         offset: 0,
                         vestaboard_name: name
                       }
                     ]
                   },
                   actor: user
                 )
                 |> Ash.create()

        assert [watcher] = installation.watchers
        assert watcher.type == :vestaboard
        assert watcher.stride == 2
        assert watcher.offset == 0
        assert watcher.vestaboard_name == name
      end
    end

    test "accepts vestaboard watcher with initial_prompt", %{user: user, network: network} do
      assert {:ok, installation} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [
                     %{
                       type: :vestaboard,
                       name: "board-with-prompt",
                       stride: 2,
                       offset: 1,
                       vestaboard_name: :panic_1,
                       initial_prompt: true
                     }
                   ]
                 },
                 actor: user
               )
               |> Ash.create()

      assert [watcher] = installation.watchers
      assert watcher.type == :vestaboard
      assert watcher.stride == 2
      assert watcher.offset == 1
      assert watcher.vestaboard_name == :panic_1
      assert watcher.initial_prompt == true
    end

    test "accepts vestaboard watcher with show_invoking", %{user: user, network: network} do
      assert {:ok, installation} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [
                     %{
                       type: :vestaboard,
                       name: "board-show-invoking",
                       stride: 3,
                       offset: 0,
                       vestaboard_name: :panic_2,
                       show_invoking: true
                     }
                   ]
                 },
                 actor: user
               )
               |> Ash.create()

      assert [watcher] = installation.watchers
      assert watcher.type == :vestaboard
      assert watcher.stride == 3
      assert watcher.offset == 0
      assert watcher.vestaboard_name == :panic_2
      assert watcher.show_invoking == true
    end

    test "rejects vestaboard watcher without vestaboard_name", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{type: :vestaboard, name: "missing-vestaboard-name", stride: 1, offset: 0}]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      assert watcher_errors[:vestaboard_name]
    end

    test "rejects vestaboard watcher with invalid name", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [
                     %{type: :vestaboard, name: "invalid-board", stride: 1, offset: 0, vestaboard_name: :invalid_name}
                   ]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      assert watcher_errors[:vestaboard_name]
    end

    test "rejects vestaboard watcher without stride/offset", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{type: :vestaboard, name: "missing-stride-offset", vestaboard_name: :panic_1}]
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
                   watchers: [
                     %{
                       type: :vestaboard,
                       name: "board-with-rows",
                       stride: 1,
                       offset: 0,
                       vestaboard_name: :panic_1,
                       rows: 2
                     }
                   ]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      assert watcher_errors[:rows]
    end

    test "rejects vestaboard watcher with offset >= stride", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [
                     %{type: :vestaboard, name: "board-invalid-offset", stride: 2, offset: 2, vestaboard_name: :panic_1}
                   ]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      assert watcher_errors[:offset]
    end

    test "rejects non-vestaboard watcher with initial_prompt", %{user: user, network: network} do
      assert {:error, changeset} =
               Installation
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   name: "Test",
                   network_id: network.id,
                   watchers: [%{type: :single, name: "single-with-prompt", stride: 1, offset: 0, initial_prompt: true}]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      assert watcher_errors[:initial_prompt]
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
                     %{type: :grid, name: "multi-grid", rows: 2, columns: 3},
                     %{type: :single, name: "multi-single", stride: 3, offset: 1},
                     %{type: :vestaboard, name: "multi-board", stride: 1, offset: 0, vestaboard_name: :panic_1}
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
                     %{type: :grid, name: "valid-grid", rows: 2, columns: 3},
                     # Invalid: offset >= stride
                     %{type: :single, name: "invalid-single", stride: 2, offset: 2},
                     # Invalid: missing vestaboard_name
                     %{type: :vestaboard, name: "invalid-board", stride: 1, offset: 0}
                   ]
                 },
                 actor: user
               )
               |> Ash.create()

      errors = errors_on(changeset)
      assert %{watchers: [watcher_errors]} = errors
      # Should have errors for both offset and the missing vestaboard_name
      assert watcher_errors[:offset] || watcher_errors[:vestaboard_name]
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
                   watchers: [%{type: :invalid_type, name: "invalid-type"}]
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
