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
          |> Ash.Changeset.for_create(:prepare_first, %{network: network, input: input}, actor: user)
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
          |> Ash.Changeset.for_create(:prepare_first, %{network: network, input: input}, actor: user)
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
    # @describetag skip: "requires API keys"
    # NOTE: these ones shouldn't be properties, because that'd be spendy. Just tests are fine.
    test "produce output" do
      user = Panic.Fixtures.user_with_tokens()
      network = Panic.Fixtures.network(user)
      # a pretty simple network, should be fast & cheap
      network =
        Panic.Engine.update_models!(network, ["stable-diffusion-test", "blip-2"], actor: user)

      input = "can you tell me a story?"

      invocation =
        network
        |> Panic.Engine.prepare_first!(input, actor: user)
        |> Panic.Engine.invoke!(actor: user)

      refute invocation.output == nil
      assert invocation.state == :completed
    end

    test "creates a next invocation with the right run number and sequence" do
      user = Panic.Fixtures.user_with_tokens()
      network = Panic.Fixtures.network_with_models(user)
      input = "can you tell me a story?"

      first =
        network
        |> Panic.Engine.prepare_first!(input, actor: user)
        |> Panic.Engine.invoke!(actor: user)

      next = Panic.Engine.prepare_next!(first, actor: user)
      assert first.run_number == next.run_number
      assert first.output == next.input
      assert first.sequence_number + 1 == next.sequence_number
    end

    test "can make a 'run' with invoke! and prepare_next! which maintains io consistency and ordering" do
      run_length = 4
      user = Panic.Fixtures.user_with_tokens()
      network = Panic.Fixtures.network_with_models(user)
      input = "can you tell me a story?"

      first =
        network
        |> Panic.Engine.prepare_first!(input, actor: user)
        |> Panic.Engine.invoke!(actor: user)

      first
      |> Stream.iterate(fn inv ->
        # IO.puts("preparing to invoke #{inv.model} with input #{inv.input}")

        inv
        |> Panic.Engine.invoke!(actor: user)
        |> Panic.Engine.prepare_next!(actor: user)
      end)
      |> Stream.take(run_length)
      |> Stream.run()

      invocations =
        Panic.Engine.list_run!(network.id, first.run_number, actor: user)

      [second_last_in_current_run, last_in_current_run] =
        Panic.Engine.current_run!(network.id, 2, actor: user)

      assert second_last_in_current_run.sequence_number == last_in_current_run.sequence_number - 1
      assert second_last_in_current_run.run_number == last_in_current_run.run_number

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
      most_recent = Panic.Engine.most_recent!(network.id, actor: user)
      assert most_recent.sequence_number == Enum.max(sequence_numbers)
    end
  end
end
