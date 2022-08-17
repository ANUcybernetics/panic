defmodule Panic.ModelsTest do
  use Panic.DataCase

  alias Panic.Models

  describe "runs" do
    alias Panic.Models.Run

    import Panic.ModelsFixtures

    @invalid_attrs %{input: nil, metadata: nil, model: nil, output: nil}

    test "list_runs/0 returns all runs" do
      run = run_fixture()
      assert Models.list_runs() == [run]
    end

    test "get_run!/1 returns the run with given id" do
      run = run_fixture()
      assert Models.get_run!(run.id) == run
    end

    test "create_run/1 with valid data creates a run" do
      valid_attrs = %{
        input: "some input",
        metadata: %{},
        model: "replicate:benswift/min-dalle",
        output: "some output"
      }

      assert {:ok, %Run{} = run} = Models.create_run(valid_attrs)
      assert run.input == "some input"
      assert run.metadata == %{}
      assert run.model == "replicate:benswift/min-dalle"
      assert run.output == "some output"
    end

    test "create_run/1 with can create a run with a parent run" do
      valid_attrs = %{
        input: "some input",
        metadata: %{},
        model: "replicate:benswift/min-dalle",
        output: "some output"
      }

      assert {:ok, %Run{} = parent_run} = Models.create_run(valid_attrs)

      valid_attrs_with_parent = Map.put(valid_attrs, :parent_id, parent_run.id)
      assert {:ok, %Run{} = run} = Models.create_run(valid_attrs_with_parent)
      assert run.parent_id == parent_run.id
    end

    test "create_run/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Models.create_run(@invalid_attrs)
    end

    test "update_run/2 with valid data updates the run" do
      run = run_fixture()

      update_attrs = %{
        input: "some updated input",
        metadata: %{},
        model: "replicate:rmokady/clip_prefix_caption",
        output: "some updated output"
      }

      assert {:ok, %Run{} = run} = Models.update_run(run, update_attrs)
      assert run.input == "some updated input"
      assert run.metadata == %{}
      assert run.model == "replicate:rmokady/clip_prefix_caption"
      assert run.output == "some updated output"
    end

    test "update_run/2 with invalid data returns error changeset" do
      run = run_fixture()
      assert {:error, %Ecto.Changeset{}} = Models.update_run(run, @invalid_attrs)
      assert run == Models.get_run!(run.id)
    end

    test "delete_run/1 deletes the run" do
      run = run_fixture()
      assert {:ok, %Run{}} = Models.delete_run(run)
      assert_raise Ecto.NoResultsError, fn -> Models.get_run!(run.id) end
    end

    test "change_run/1 returns a run changeset" do
      run = run_fixture()
      assert %Ecto.Changeset{} = Models.change_run(run)
    end
  end
end
