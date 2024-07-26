defmodule Panic.InvocationTest do
  use Panic.DataCase
  use ExUnitProperties
  alias Panic.Engine.Invocation

  describe "CRUD actions" do
    # now if our action inputs are invalid when we think they should be valid, we will find out here
    property "accepts all valid input (with networks of length at least 1)" do
      check all(input <- input_for_prepare_first(min_length: 1)) do
        assert %Ash.Changeset{valid?: true} =
                 Panic.Engine.changeset_to_prepare_first(
                   input.network,
                   input.input,
                   authorize?: false
                 )
      end
    end

    property "throws error when network has no models" do
      check all(input <- input_for_prepare_first(length: 0)) do
        assert %Ash.Changeset{valid?: false} =
                 Panic.Engine.changeset_to_prepare_first(
                   input.network,
                   input.input,
                   authorize?: false
                 )
      end
    end

    property "gives error changeset when :input is invalid" do
      user = Panic.Generators.user_fixture()

      check all(
              input <-
                Ash.Generator.action_input(Panic.Engine.Invocation, :prepare_first, %{
                  network: Panic.Generators.network(user, min_length: 1),
                  input: integer()
                })
            ) do
        assert %Ash.Changeset{valid?: false} =
                 Panic.Engine.changeset_to_prepare_first(
                   input.network,
                   input.input,
                   authorize?: false
                 )
      end
    end

    property "succeeds on all valid input" do
      user = Panic.Generators.user_fixture()

      check all(input <- input_for_prepare_first(min_length: 1)) do
        invocation =
          Invocation
          |> Ash.Changeset.for_create(:prepare_first, input, actor: user)
          |> Ash.create!()

        assert invocation.network_id == input.network.id
        assert invocation.input == input.input
        assert invocation.output == nil
        assert invocation.sequence_number == 0
        assert invocation.run_number == invocation.id
      end
    end

    property "succeeds on all valid input (code interface version)" do
      check all(input <- input_for_prepare_first(min_length: 1)) do
        Panic.Engine.prepare_first!(
          input.network,
          input.input,
          authorize?: false
        )
      end
    end

    # TODO what's the best way with property testing to test that it gives the right invalid changeset on invalid input?

    property "Invocation missing read action throws Invalid error" do
      user = Panic.Generators.user_fixture()

      check all(invocation <- Panic.Generators.first_invocation(user)) do
        assert invocation.id == Panic.Engine.get_invocation!(invocation.id).id
        # there shouldn't ever be a negative ID in the db, so this should always raise
        assert_raise Ash.Error.Query.NotFound, fn -> Panic.Engine.get_invocation!(-1) end
      end
    end

    property "Invocation pre-invocation has no output" do
      user = Panic.Generators.user_fixture()

      check all(invocation <- Panic.Generators.first_invocation(user)) do
        refute invocation.input == nil
        assert invocation.output == nil
        assert invocation.id == invocation.run_number
      end
    end

    property "invoke the invocation" do
      user = Panic.Generators.user_fixture()

      check all(invocation <- Panic.Generators.first_invocation(user)) do
        invoked = Panic.Engine.invoke!(invocation)
        refute invoked.output == nil
      end
    end

    property "invoke and prepare next" do
      user = Panic.Generators.user_fixture()

      check all(invocation <- Panic.Generators.first_invocation(user)) do
        invoked = Panic.Engine.invoke!(invocation)
        next = Panic.Engine.prepare_next!(invoked)
        assert invoked.run_number == next.run_number
        assert invoked.sequence_number + 1 == next.sequence_number
      end
    end

    # this is a big test - almost an integration test
    property "create a run of invocations" do
      run_length = 100

      user = Panic.Generators.user_fixture()
      first_invocation = Panic.Generators.first_invocation(user) |> pick()
      network_id = first_invocation.network.id

      first_invocation
      |> Stream.iterate(fn inv ->
        inv
        |> Panic.Engine.invoke!()
        |> Panic.Engine.prepare_next!()
      end)
      |> Stream.take(run_length)
      |> Stream.run()

      invocations =
        Panic.Engine.all_in_run!(network_id, first_invocation.run_number)

      invocations
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [a, b] ->
        assert a.output == b.input
      end)

      assert Enum.count(invocations) == run_length
      sequence_numbers = Enum.map(invocations, & &1.sequence_number)
      assert sequence_numbers = Enum.sort(sequence_numbers, :asc)

      most_recent = Panic.Engine.most_recent_invocation!(network_id)
      assert most_recent.sequence_number == Enum.max(sequence_numbers)
    end
  end

  defp input_for_prepare_first(opts) do
    user = Panic.Generators.user_fixture()

    Ash.Generator.action_input(Panic.Engine.Invocation, :prepare_first, %{
      network: Panic.Generators.network(user, opts)
    })
  end
end
