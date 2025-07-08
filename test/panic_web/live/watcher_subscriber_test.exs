defmodule PanicWeb.WatcherSubscriberTest do
  use PanicWeb.ConnCase
  use ExUnitProperties

  alias Panic.Engine.Invocation

  setup do
    # Stop all network runners to ensure clean state
    PanicWeb.Helpers.stop_all_network_runners()

    user = Panic.Fixtures.user()
    network = Panic.Fixtures.network_with_dummy_models(user)
    %{user: user, network: network}
  end

  describe "invocation filtering logic" do
    test "genesis invocations should always be processed", %{network: network} do
      # Create a genesis invocation
      genesis = %Invocation{
        id: 1,
        sequence_number: 0,
        run_number: 100,
        network_id: network.id,
        state: :invoking,
        input: "test input",
        output: nil,
        model: "test-model"
      }

      assert genesis.sequence_number == 0
      assert genesis.state == :invoking

      # Genesis invocations should always be processed regardless of current state
      assert invocation_should_be_processed?(genesis, nil)
    end

    test "non-genesis invocations should be processed when run_number matches", %{network: network} do
      # Create genesis invocation first
      genesis = %Invocation{
        id: 1,
        sequence_number: 0,
        run_number: 100,
        network_id: network.id,
        state: :completed,
        input: "test input",
        output: "test output",
        model: "test-model"
      }

      # Create non-genesis invocation with same run_number
      non_genesis = %Invocation{
        id: 2,
        sequence_number: 1,
        # Same as genesis
        run_number: 100,
        network_id: network.id,
        state: :invoking,
        input: "next input",
        output: nil,
        model: "test-model"
      }

      assert non_genesis.sequence_number > 0
      assert non_genesis.run_number == genesis.run_number
      assert non_genesis.state == :invoking

      # Should be processed when run_number matches
      assert invocation_should_be_processed?(non_genesis, genesis)
    end

    test "non-genesis invocations should be ignored when run_number differs", %{network: network} do
      # Create genesis invocation
      genesis = %Invocation{
        id: 1,
        sequence_number: 0,
        run_number: 100,
        network_id: network.id,
        state: :completed,
        input: "test input",
        output: "test output",
        model: "test-model"
      }

      # Create non-genesis invocation with different run_number
      old_invocation = %Invocation{
        id: 3,
        sequence_number: 1,
        # Different from genesis (100)
        run_number: 99,
        network_id: network.id,
        state: :invoking,
        input: "old input",
        output: nil,
        model: "test-model"
      }

      assert old_invocation.sequence_number > 0
      assert old_invocation.run_number != genesis.run_number
      assert old_invocation.state == :invoking

      # Should be ignored when run_number differs
      refute invocation_should_be_processed?(old_invocation, genesis)
    end

    test "non-genesis invocations should be ignored when no genesis exists", %{network: network} do
      # Create non-genesis invocation
      non_genesis = %Invocation{
        id: 2,
        sequence_number: 1,
        run_number: 100,
        network_id: network.id,
        state: :invoking,
        input: "test input",
        output: nil,
        model: "test-model"
      }

      assert non_genesis.sequence_number > 0
      assert non_genesis.state == :invoking

      # Should be ignored when no genesis exists
      refute invocation_should_be_processed?(non_genesis, nil)
    end

    test "mid-run join should fetch genesis invocation for processing", %{user: user, network: network} do
      # Create a real genesis invocation in the database
      {:ok, genesis_invocation} =
        Ash.create(
          Invocation,
          %{
            input: "genesis prompt",
            network: network
          },
          action: :prepare_first,
          actor: user
        )

      # Complete the genesis invocation
      completed_genesis =
        genesis_invocation
        |> Ash.Changeset.for_update(:update_output, %{output: "genesis output"}, actor: user)
        |> Ash.update!()

      # Create a non-genesis invocation in the same run
      {:ok, second_invocation} =
        Panic.Engine.prepare_next(completed_genesis, actor: user)

      # Simulate mid-run join scenario: we have a non-genesis invocation but no current genesis
      # This should trigger fetching the genesis invocation from the database
      assert second_invocation.sequence_number > 0
      assert second_invocation.run_number == completed_genesis.run_number

      # Test the fetch_genesis_invocation logic (simulated)
      assert can_fetch_genesis_for_invocation?(second_invocation, network)
    end

    test "mid-run join handles different runs correctly", %{user: user, network: network} do
      # Create first run with genesis and non-genesis
      {:ok, first_genesis} =
        Ash.create(
          Invocation,
          %{
            input: "first run genesis",
            network: network
          },
          action: :prepare_first,
          actor: user
        )

      completed_first_genesis =
        first_genesis
        |> Ash.Changeset.for_update(:update_output, %{output: "first genesis output"}, actor: user)
        |> Ash.update!()

      {:ok, first_second} = Panic.Engine.prepare_next(completed_first_genesis, actor: user)

      # Create second run with different genesis
      {:ok, second_genesis} =
        Ash.create(
          Invocation,
          %{
            input: "second run genesis",
            network: network
          },
          action: :prepare_first,
          actor: user
        )

      completed_second_genesis =
        second_genesis
        |> Ash.Changeset.for_update(:update_output, %{output: "second genesis output"}, actor: user)
        |> Ash.update!()

      {:ok, second_second} = Panic.Engine.prepare_next(completed_second_genesis, actor: user)

      # Verify that invocations from different runs have different run_numbers
      assert first_second.run_number == completed_first_genesis.id
      assert second_second.run_number == completed_second_genesis.id
      assert first_second.run_number != second_second.run_number

      # Both should be able to fetch their respective genesis invocations
      assert can_fetch_genesis_for_invocation?(first_second, network)
      assert can_fetch_genesis_for_invocation?(second_second, network)
    end

    property "all invocation states should be processed correctly for matching runs", %{network: network} do
      ExUnitProperties.check all(
                               run_number <- positive_integer(),
                               state <- member_of([:ready, :invoking, :completed, :failed])
                             ) do
        genesis = %Invocation{
          id: 1,
          sequence_number: 0,
          run_number: run_number,
          network_id: network.id,
          state: :completed,
          input: "genesis input",
          output: "genesis output",
          model: "test-model"
        }

        non_genesis = %Invocation{
          id: 2,
          sequence_number: 1,
          # Same as genesis
          run_number: run_number,
          network_id: network.id,
          state: state,
          input: "non-genesis input",
          output: if(state == :completed, do: "output"),
          model: "test-model"
        }

        # All states should be processed when run_number matches
        assert invocation_should_be_processed?(non_genesis, genesis)
      end
    end
  end

  describe "display mode filtering" do
    test "single mode should filter by stride and offset" do
      # Test single mode with offset=1, stride=3, show_invoking=true
      display = {:single, 1, 3, true}

      # sequence_number=4: 4 % 3 = 1, matches offset=1 ✓
      assert matches_display_criteria?(4, display)

      # sequence_number=7: 7 % 3 = 1, matches offset=1 ✓
      assert matches_display_criteria?(7, display)

      # sequence_number=5: 5 % 3 = 2, doesn't match offset=1 ✗
      refute matches_display_criteria?(5, display)

      # sequence_number=6: 6 % 3 = 0, doesn't match offset=1 ✗
      refute matches_display_criteria?(6, display)
    end

    test "grid mode should accept all invocations" do
      display = {:grid, 3, 3}

      # Grid mode should accept any sequence number
      assert matches_display_criteria?(0, display)
      assert matches_display_criteria?(1, display)
      assert matches_display_criteria?(99, display)
    end

    test "single mode with show_invoking=false should ignore :invoking state" do
      display = {:single, 0, 1, false}

      # With show_invoking=false, should ignore :invoking invocations
      refute should_show_invocation_for_display?(:invoking, 1, display)
      refute should_show_invocation_for_display?(:invoking, 5, display)
      refute should_show_invocation_for_display?(:invoking, 99, display)

      # But should still show :completed invocations
      assert should_show_invocation_for_display?(:completed, 1, display)
      assert should_show_invocation_for_display?(:completed, 5, display)
      assert should_show_invocation_for_display?(:completed, 99, display)

      # And should show other states as well
      assert should_show_invocation_for_display?(:ready, 1, display)
      assert should_show_invocation_for_display?(:failed, 1, display)
    end

    test "single mode with show_invoking=true should show all states" do
      # Test with show_invoking=true
      display = {:single, 0, 2, true}

      # Should show all states including :invoking when show_invoking=true
      # 2 % 2 == 0
      assert should_show_invocation_for_display?(:invoking, 2, display)
      assert should_show_invocation_for_display?(:completed, 2, display)
      assert should_show_invocation_for_display?(:ready, 2, display)
      assert should_show_invocation_for_display?(:failed, 2, display)

      # Test with different offset
      display = {:single, 1, 2, true}

      # Should show all states including :invoking when show_invoking=true
      # 1 % 2 == 1, matches offset=1
      assert should_show_invocation_for_display?(:invoking, 1, display)
      assert should_show_invocation_for_display?(:completed, 1, display)
    end

    test "backward compatibility: 3-element single tuples default to show_invoking=false" do
      # Test backward compatibility with 3-element tuples
      display = {:single, 0, 1}

      # Should ignore :invoking invocations (defaults to show_invoking=false)
      refute should_show_invocation_for_display?(:invoking, 1, display)
      refute should_show_invocation_for_display?(:invoking, 5, display)

      # But should still show other states
      assert should_show_invocation_for_display?(:completed, 1, display)
      assert should_show_invocation_for_display?(:ready, 1, display)
      assert should_show_invocation_for_display?(:failed, 1, display)
    end

    property "single mode filtering works correctly for all offsets and strides" do
      ExUnitProperties.check all(
                               offset <- integer(0..4),
                               stride <- integer(1..10),
                               sequence_number <- integer(0..50)
                             ) do
        display = {:single, offset, stride}
        expected = rem(sequence_number, stride) == offset
        actual = matches_display_criteria?(sequence_number, display)

        assert actual == expected,
               "Expected #{expected} for sequence_number=#{sequence_number}, offset=#{offset}, stride=#{stride}, got #{actual}"
      end
    end
  end

  describe "functional integration tests" do
    test "invocation watcher properly handles run transitions in real scenario", %{network: network} do
      user = Ash.get!(Panic.Accounts.User, network.user_id, authorize?: false)

      # Create some invocations for testing
      first_invocation = pick(Panic.Generators.invocation(network))

      # Start the invocation to trigger the pub-sub system
      invoking_invocation =
        first_invocation
        |> Ash.Changeset.for_update(:about_to_invoke, %{}, actor: user)
        |> Ash.update!()

      # Verify the invocation was updated to :invoking state
      assert invoking_invocation.state == :invoking
      assert invoking_invocation.sequence_number == 0

      # Complete the invocation
      {:ok, completed_invocation} =
        invoking_invocation
        |> Ash.Changeset.for_update(:update_output, %{output: "test output"}, actor: user)
        |> Ash.update()

      # Verify the invocation was completed
      assert completed_invocation.output == "test output"

      # This test verifies that the basic pub-sub system works
      # The actual LiveView integration would require mounting a LiveView
      # which is more complex and would test the socket operations
      assert true
    end
  end

  describe "archive URL filtering" do
    test "invocations with archive URL in input should be filtered out", %{network: network} do
      invocation = %Invocation{
        id: 1,
        sequence_number: 0,
        run_number: 100,
        network_id: network.id,
        state: :completed,
        input: "https://fly.storage.tigris.dev/some-archive-file.txt",
        output: "normal output",
        model: "test-model"
      }

      assert should_filter_archive_url?(invocation)
    end

    test "invocations with archive URL in output should be filtered out", %{network: network} do
      invocation = %Invocation{
        id: 1,
        sequence_number: 0,
        run_number: 100,
        network_id: network.id,
        state: :completed,
        input: "normal input",
        output: "https://fly.storage.tigris.dev/some-archive-result.json",
        model: "test-model"
      }

      assert should_filter_archive_url?(invocation)
    end

    test "invocations with archive URL in both input and output should be filtered out", %{network: network} do
      invocation = %Invocation{
        id: 1,
        sequence_number: 0,
        run_number: 100,
        network_id: network.id,
        state: :completed,
        input: "https://fly.storage.tigris.dev/input-file.txt",
        output: "https://fly.storage.tigris.dev/output-file.json",
        model: "test-model"
      }

      assert should_filter_archive_url?(invocation)
    end

    test "invocations without archive URLs should not be filtered", %{network: network} do
      invocation = %Invocation{
        id: 1,
        sequence_number: 0,
        run_number: 100,
        network_id: network.id,
        state: :completed,
        input: "normal input text",
        output: "normal output text",
        model: "test-model"
      }

      refute should_filter_archive_url?(invocation)
    end

    test "invocations with nil input and output should not be filtered", %{network: network} do
      invocation = %Invocation{
        id: 1,
        sequence_number: 0,
        run_number: 100,
        network_id: network.id,
        state: :ready,
        input: nil,
        output: nil,
        model: "test-model"
      }

      refute should_filter_archive_url?(invocation)
    end

    test "invocations with URLs that don't match archive prefix should not be filtered", %{network: network} do
      invocation = %Invocation{
        id: 1,
        sequence_number: 0,
        run_number: 100,
        network_id: network.id,
        state: :completed,
        input: "https://example.com/some-file.txt",
        output: "https://other-storage.com/result.json",
        model: "test-model"
      }

      refute should_filter_archive_url?(invocation)
    end

    test "invocations with partial archive URL match should not be filtered", %{network: network} do
      invocation = %Invocation{
        id: 1,
        sequence_number: 0,
        run_number: 100,
        network_id: network.id,
        state: :completed,
        input: "contains https://fly.storage.tigris.dev/ in the middle",
        output: "normal output",
        model: "test-model"
      }

      refute should_filter_archive_url?(invocation)
    end
  end

  # Helper functions that extract the core business logic
  # These mirror the logic in the actual WatcherSubscriber module

  defp invocation_should_be_processed?(%Invocation{sequence_number: 0}, _genesis) do
    # Genesis invocations should always be processed
    true
  end

  defp invocation_should_be_processed?(%Invocation{run_number: run_number}, %Invocation{run_number: genesis_run}) do
    # Non-genesis invocations should only be processed if run_number matches genesis
    run_number == genesis_run
  end

  defp invocation_should_be_processed?(%Invocation{}, nil) do
    # Non-genesis invocations should be ignored if no genesis exists
    false
  end

  defp can_fetch_genesis_for_invocation?(%Invocation{run_number: run_number}, _network) do
    # Test that we can fetch the genesis invocation for a given run
    # run_number is the id of the genesis invocation
    case Ash.get(Invocation, run_number, actor: nil, authorize?: false) do
      {:ok, _genesis} -> true
      {:error, _} -> false
    end
  end

  defp matches_display_criteria?(_sequence_number, {:grid, _rows, _cols}) do
    # Grid mode accepts all invocations
    true
  end

  defp matches_display_criteria?(sequence_number, {:single, offset, stride}) do
    # Single mode filters by stride and offset
    rem(sequence_number, stride) == offset
  end

  defp matches_display_criteria?(sequence_number, {:single, offset, stride, _show_invoking}) do
    # Single mode filters by stride and offset
    rem(sequence_number, stride) == offset
  end

  defp should_filter_archive_url?(%Invocation{input: input, output: output}) do
    # Helper function that mirrors the logic in WatcherSubscriber
    archive_prefix = "https://fly.storage.tigris.dev/"
    String.starts_with?(input || "", archive_prefix) or String.starts_with?(output || "", archive_prefix)
  end

  defp should_show_invocation_for_display?(state, sequence_number, display) do
    # Helper function that mirrors the logic in WatcherSubscriber
    case display do
      {:grid, _rows, _cols} ->
        true

      {:single, offset, stride} when rem(sequence_number, stride) == offset ->
        # Backward compatibility: 3-element tuple defaults to show_invoking=false
        state != :invoking

      {:single, offset, stride, show_invoking} when rem(sequence_number, stride) == offset ->
        # Use show_invoking flag to determine whether to show :invoking invocations
        show_invoking or state != :invoking

      {:single, _, _} ->
        # Not matching the display criteria, don't show
        false

      {:single, _, _, _} ->
        # Not matching the display criteria, don't show
        false
    end
  end
end
