defmodule Panic.ModelsTest do
  use Panic.DataCase
  alias Panic.Models.Invocation

  describe "Panic.Models.Invocation resource" do
    test "changeset for :create action with valid data creates an invocation" do
      valid_attrs = %{
        model: Panic.Topology,
        input: "a test input",
        run_number: 0
      }

      invocation =
        Invocation
        |> Ash.Changeset.for_create(:invoke, valid_attrs)
        |> Ash.create!()

      assert invocation.model == valid_attrs.model
      assert invocation.input == valid_attrs.input
      assert invocation.run_number == valid_attrs.run_number
    end

    test "raise if there's no Invocation with a given id" do
      assert_raise Ash.Error.Invalid, fn -> Ash.get!(Invocation, 1234) end
    end

    test "read the created invocation back from the db" do
      %Invocation{id: invocation_id} = invocation_fixture()

      assert %Invocation{id: ^invocation_id} =
               Panic.Models.get_invocation!(invocation_id)
    end
  end

  # # used to be in a separate e, but not necessary for now
  defp invocation_fixture(attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          model: Panic.Topology,
          input: "a test input",
          run_number: 0
        },
        attrs
      )

    Invocation
    |> Ash.Changeset.for_create(:invoke, attrs)
    |> Ash.create!()
  end
end
