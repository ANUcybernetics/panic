defmodule Panic.ObanTest do
  use Panic.DataCase
  use ExUnitProperties
  use Oban.Testing, repo: Panic.Repo

  alias Panic.Engine.Invocation

  defp drain_default_queue(limit) do
    Oban.drain_queue(queue: :default, with_limit: 1, with_recursion: true)
  end

  describe "Oban-powered Panic.Workers.Invoker" do
    @describetag skip: "requires API keys"

    test "has a working perform/1 callback" do
      user = Panic.Fixtures.user_with_tokens()
      network = Panic.Fixtures.network_with_models(user)

      invocation =
        Panic.Engine.prepare_first!(network, "can you tell me a story?", actor: user)

      assert :ok =
               perform_job(Panic.Workers.Invoker, %{
                 "user_id" => user.id,
                 "invocation_id" => invocation.id,
                 "network_id" => invocation.network_id,
                 "run_number" => invocation.run_number,
                 "sequence_number" => invocation.sequence_number
               })
    end

    @tag timeout: 120_000
    test "can be successfully run for 10 invocations and then stopped" do
      # NOTE this doesn't currently work, because Oban.drain_queue/2 doesn't seem to
      # honour the :with_limit option when combined with :with_recursion == true
      user = Panic.Fixtures.user_with_tokens()
      network = Panic.Fixtures.network_with_models(user)

      invocation =
        Panic.Engine.prepare_first!(network, "can you tell me a story?", actor: user)

      IO.puts("about to run a 10-invocation integration test of the core Panic engine")

      Panic.Engine.start_run!(invocation, actor: user)
      drain_default_queue(10)

      Panic.Engine.stop_run!(network.id, actor: user)

      assert [] = all_enqueued()

      invocations =
        Panic.Engine.list_run!(network.id, invocation.run_number, actor: user)

      assert length(invocations) == 10

      # check some invariants
      invocations
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [a, b] ->
        assert a.output == b.input
        assert a.sequence_number == b.sequence_number - 1
        assert a.run_number == invocation.run_number
        assert a.network_id == invocation.network_id
      end)

      # assert {:ok, %Invocation{output: nil}} =
      #          Ash.get(Invocation, too_early_invocation.id, actor: user)

      assert {:ok, %Invocation{output: output}} = Ash.get(Invocation, invocation.id, actor: user)
      assert is_binary(output) and output != ""
    end
  end
end
