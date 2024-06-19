defmodule Panic.InvocationTest do
  use Panic.DataCase
  use ExUnitProperties
  alias Panic.Engine.Invocation

  describe "CRUD actions" do
    # now if our action inputs are invalid when we think they should be valid, we will find out here
    property "accepts all valid input (with networks of length at least 1)" do
      check all(input <- input_for_create_first(min_length: 1)) do
        assert %Ash.Changeset{valid?: true} =
                 Panic.Engine.changeset_to_create_first(
                   input.network,
                   input.input,
                   authorize?: false
                 )
      end
    end

    property "throws error when network has no models" do
      check all(input <- input_for_create_first(length: 0)) do
        assert %Ash.Changeset{valid?: false} =
                 Panic.Engine.changeset_to_create_first(
                   input.network,
                   input.input,
                   authorize?: false
                 )
      end
    end

    property "gives error changeset when :input is invalid" do
      check all(input <-
        Ash.Generator.action_input(Panic.Engine.Invocation, :create_first, %{
          network: Panic.Generators.network(min_length: 1),
          input: integer()
        })
      ) do
        assert %Ash.Changeset{valid?: false} =
                 Panic.Engine.changeset_to_create_first(
                   input.network,
                   input.input,
                   authorize?: false
                 )
      end
    end

    property "succeeds on all valid input" do
      check all(input <- input_for_create_first(min_length: 1)) do
        Invocation
        |> Ash.Changeset.for_create(:create_first, input)
        |> Ash.create!()
      end
    end

    property "succeeds on all valid input (code interface version)" do
      check all(input <- input_for_create_first(min_length: 1)) do
        {:ok, invocation} =
          Panic.Engine.create_first(
            input.network,
            input.input,
            authorize?: false
          )

        assert invocation.input == input.input
        # FIXME there might be an issue here with "" vs nil?
        # assert invocation.description == input.description
        assert invocation.network == input.network
        assert is_nil(invocation.output)
      end
    end

    # TODO what's the best way with property testing to test that it gives the right invalid changeset on invalid input?

    property "Invocation read action" do
      check all(invocation <- Panic.Generators.invocation()) do
        assert invocation.id == Panic.Engine.get_invocation!(invocation.id).id
        # there shouldn't ever be a negative ID in the db, so this should always raise
        assert_raise Ash.Error.Invalid, fn -> Ash.get!(Invocation, -1) end
      end
    end

    property "Invocation finalise action" do
      check all(invocation <- Panic.Generators.invocation()) do
        assert invocation.output == "not yet done"
      end
    end
  end

  defp input_for_create_first(opts) do
    Ash.Generator.action_input(Panic.Engine.Invocation, :create_first, %{
      network: Panic.Generators.network(opts)
    })
  end
end
