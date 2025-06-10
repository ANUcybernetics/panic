defmodule Panic.InvocationTest do
  use Panic.DataCase
  use ExUnitProperties

  alias Ash.Error.Invalid
  alias Panic.Engine.Invocation

  describe "Invocation CRUD operations" do
    property "accepts valid input with non-empty networks" do
      user = Panic.Fixtures.user()

      check all(
              network <- Panic.Generators.network_with_dummy_models(user),
              input <- Panic.Generators.ascii_sentence()
            ) do
        assert %Ash.Changeset{valid?: true} =
                 Panic.Engine.changeset_to_prepare_first(
                   network,
                   input
                 )
      end
    end

    property "enforces unique combination of network_id, run_number, and sequence_number" do
      user = Panic.Fixtures.user()

      check all(
              network <- Panic.Generators.network_with_dummy_models(user),
              input <- Panic.Generators.ascii_sentence()
            ) do
        # Create the first invocation
        first_invocation =
          Invocation
          |> Ash.Changeset.for_create(:prepare_first, %{network: network, input: input}, actor: user)
          |> Ash.create!()

        # Fetch the invocation using the unique_in_run identity
        fetched_invocation =
          Ash.get!(
            Invocation,
            %{
              network_id: first_invocation.network_id,
              run_number: first_invocation.run_number,
              sequence_number: first_invocation.sequence_number
            },
            actor: user
          )

        # Check for equality
        assert fetched_invocation.id == first_invocation.id
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
              network <- Panic.Generators.network_with_dummy_models(user),
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
              network <- Panic.Generators.network_with_dummy_models(user),
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
              network <- Panic.Generators.network_with_dummy_models(user),
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
              network <- Panic.Generators.network_with_dummy_models(user),
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

      assert_raise Invalid, fn ->
        Ash.get!(Invocation, -1, actor: user)
      end

      assert_raise Ash.Error.Forbidden, fn ->
        Ash.get!(Invocation, 1)
      end
    end

    property "initial invocation has no output" do
      user = Panic.Fixtures.user()

      check all(
              network <- Panic.Generators.network_with_dummy_models(user),
              input <- Panic.Generators.ascii_sentence()
            ) do
        invocation = Panic.Engine.prepare_first!(network, input, actor: user)
        refute invocation.input == nil
        assert invocation.output == nil
        assert invocation.id == invocation.run_number
      end
    end
  end

  describe "Invocation with dummy models" do
    test "produces dummy output" do
      user = Panic.Fixtures.user()
      # Use dummy models that don't require real API calls
      network =
        user
        |> Panic.Fixtures.network()
        |> Panic.Engine.update_models!([["dummy-t2i"], ["dummy-i2t"]], actor: user)

      input = "can you tell me a story?"

      invocation =
        network
        |> Panic.Engine.prepare_first!(input, actor: user)
        |> Panic.Engine.invoke!(actor: user)

      refute invocation.output == nil
      assert invocation.state == :completed
      # Dummy image output should start with the dummy URL
      assert String.starts_with?(invocation.output, "https://dummy-images.test/")
    end

    test "creates a next invocation with the right run number and sequence using dummy models" do
      user = Panic.Fixtures.user()
      network = Panic.Fixtures.network_with_dummy_models(user)
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

    test "can make a 'run' with invoke! and prepare_next! which maintains io consistency and ordering using dummy models" do
      run_length = 4
      user = Panic.Fixtures.user()
      network = Panic.Fixtures.network_with_dummy_models(user)
      input = "can you tell me a story?"

      first =
        network
        |> Panic.Engine.prepare_first!(input, actor: user)
        |> Panic.Engine.invoke!(actor: user)

      first
      |> Stream.iterate(fn inv ->
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

  describe "Token validation with dummy models" do
    test "user can create invocation with dummy models (no token required)" do
      user = Panic.Fixtures.user()

      # Create a network with only dummy models - no tokens should be required
      network =
        user
        |> Panic.Fixtures.network()
        |> Panic.Engine.update_models!([["dummy-t2a"], ["dummy-a2t"]], actor: user)

      input = "generate some audio"

      # Create and prepare the invocation - should work without any tokens
      invocation = Panic.Engine.prepare_first!(network, input, actor: user)

      # Verify the invocation was created successfully
      assert invocation.network_id == network.id
      assert invocation.input == input
      assert invocation.model == ["dummy-t2a"]
    end

    test "user can invoke dummy models without any tokens" do
      user = Panic.Fixtures.user()

      # Create a network with dummy models
      network =
        user
        |> Panic.Fixtures.network()
        |> Panic.Engine.update_models!([["dummy-t2a"], ["dummy-a2t"]], actor: user)

      input = "generate some audio"

      # Create first invocation and invoke it (dummy model should work without tokens)
      first_invocation = Panic.Engine.prepare_first!(network, input, actor: user)
      first_invocation = Panic.Engine.invoke!(first_invocation, actor: user)

      # Prepare and invoke next invocation (also dummy model)
      second_invocation = Panic.Engine.prepare_next!(first_invocation, actor: user)
      second_invocation = Panic.Engine.invoke!(second_invocation, actor: user)

      # Both should succeed without any tokens
      assert first_invocation.state == :completed
      assert second_invocation.state == :completed
      assert String.starts_with?(first_invocation.output, "https://dummy-audio.test/")
      assert String.starts_with?(second_invocation.output, "DUMMY_TRANSCRIPT:")
    end
  end
end
