defmodule Panic.InvocationTest do
  use Panic.DataCase
  use ExUnitProperties
  alias Panic.Engine.Invocation

  describe "Invocation CRUD operations" do
    property "accepts valid input with non-empty networks" do
      user = Panic.Fixtures.user()

      check all(
              network <- Panic.Generators.network_with_models(user),
              input <- Panic.Generators.ascii_sentence()
            ) do
        assert %Ash.Changeset{valid?: true} =
                 Panic.Engine.changeset_to_prepare_first(
                   network,
                   input
                 )
      end
    end

    property "rejects preparation when network has no models" do
      user = Panic.Fixtures.user()

      check all(
              network <- Panic.Generators.network(user),
              input <- Panic.Generators.ascii_sentence()
            ) do
        assert %Ash.Changeset{valid?: false} =
                 Panic.Engine.changeset_to_prepare_first(
                   network,
                   input
                 )
      end
    end

    property "returns error changeset for invalid input" do
      user = Panic.Fixtures.user()

      check all(
              network <- Panic.Generators.network_with_models(user),
              input <- integer()
            ) do
        assert %Ash.Changeset{valid?: false} =
                 Panic.Engine.changeset_to_prepare_first(
                   network,
                   input,
                   actor: user
                 )
      end
    end

    property "can creates invocation using :prepare_first" do
      user = Panic.Fixtures.user()

      check all(
              network <- Panic.Generators.network_with_models(user),
              input <- Panic.Generators.ascii_sentence()
            ) do
        invocation =
          Invocation
          |> Ash.Changeset.for_create(:prepare_first, %{network: network, input: input},
            actor: user
          )
          |> Ash.create!()

        assert invocation.network_id == network.id
        assert invocation.input == input
        assert invocation.output == nil
        assert invocation.sequence_number == 0
        assert invocation.run_number == invocation.id
      end
    end

    property "creates invocation with correct attributes" do
      user = Panic.Fixtures.user()

      check all(
              network <- Panic.Generators.network_with_models(user),
              input <- Panic.Generators.ascii_sentence()
            ) do
        invocation =
          Invocation
          |> Ash.Changeset.for_create(:prepare_first, %{network: network, input: input},
            actor: user
          )
          |> Ash.create!()

        assert invocation.network_id == network.id
        assert invocation.input == input
        assert invocation.output == nil
        assert invocation.sequence_number == 0
        assert invocation.run_number == invocation.id
      end
    end

    property "prepares first invocation using code interface" do
      user = Panic.Fixtures.user()

      check all(
              network <- Panic.Generators.network_with_models(user),
              input <- Panic.Generators.ascii_sentence()
            ) do
        Panic.Engine.prepare_first!(
          network,
          input,
          actor: user
        )
      end
    end

    # TODO what's the best way with property testing to test that it gives the right invalid changeset on invalid input?

    property "raises the correct error for non-existent or forbidden invocations" do
      user = Panic.Fixtures.user()

      assert_raise Ash.Error.Invalid, fn ->
        Ash.get!(Panic.Engine.Invocation, -1, actor: user)
      end

      assert_raise Ash.Error.Forbidden, fn ->
        Ash.get!(Panic.Engine.Invocation, 1)
      end
    end

    property "initial invocation has no output" do
      user = Panic.Fixtures.user()

      check all(
              network <- Panic.Generators.network_with_models(user),
              input <- Panic.Generators.ascii_sentence()
            ) do
        invocation = Panic.Engine.prepare_first!(network, input, actor: user)
        refute invocation.input == nil
        assert invocation.output == nil
        assert invocation.id == invocation.run_number
      end
    end
  end

  describe "Invocation with API calls" do
    property "invocation produces output" do
      user = Panic.Fixtures.user_with_tokens()

      check all(
              network <- Panic.Generators.network_with_models(user),
              input <- Panic.Generators.ascii_sentence()
            ) do
        invocation = Panic.Engine.prepare_first!(network, input, actor: user)
        invoked = Panic.Engine.invoke!(invocation, actor: user)
        refute invoked.output == nil
      end
    end

    property "next invocation maintains run number and increments sequence" do
      user = Panic.Fixtures.user()

      check all(
              network <- Panic.Generators.network_with_models(user),
              input <- Panic.Generators.ascii_sentence()
            ) do
        invocation = Panic.Engine.prepare_first!(network, input)
        invoked = Panic.Engine.invoke!(invocation)
        next = Panic.Engine.prepare_next!(invoked)
        assert invoked.run_number == next.run_number
        assert invoked.sequence_number + 1 == next.sequence_number
      end
    end

    property "run of invocations maintains consistency and order" do
      run_length = 4
      user = Panic.Fixtures.user()

      check all(
              network <- Panic.Generators.network_with_models(user),
              input <- string(:printable, min_length: 1)
            ) do
        first_invocation = Panic.Engine.prepare_first!(network, input)

        first_invocation
        |> Stream.iterate(fn inv ->
          inv
          |> Panic.Engine.invoke!()
          |> Panic.Engine.prepare_next!()
        end)
        |> Stream.take(run_length)
        |> Stream.run()

        invocations =
          Panic.Engine.all_in_run!(network.id, first_invocation.run_number)

        # check outputs match inputs
        invocations
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.each(fn [a, b] ->
          assert a.output == b.input
        end)

        # check the right number of invocations generated, and returned in the right order
        assert Enum.count(invocations) == run_length
        sequence_numbers = Enum.map(invocations, & &1.sequence_number)
        assert sequence_numbers = Enum.sort(sequence_numbers, :asc)

        # check the most recent invocation action works
        [most_recent] = Panic.Engine.most_recent_invocations!(network.id, 1)
        assert most_recent.sequence_number == Enum.max(sequence_numbers)
      end
    end
  end
end
