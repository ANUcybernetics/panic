defmodule Panic.ObanTest do
  use Panic.DataCase
  use ExUnitProperties
  use Oban.Testing, repo: Panic.Repo
  # alias Panic.Engine.Invocation

  describe "Oban-powered Panic.Workers.Invoker" do
    @describetag skip: "requires API keys"

    @tag timeout: 120_000
    test "can be successfully started, run for 30s and stopped" do
      user = Panic.Fixtures.user_with_tokens()
      network = Panic.Fixtures.network_with_models(user)

      invocation =
        network
        |> Panic.Engine.prepare_first!("can you tell me a story?", actor: user)

      IO.puts("about to run a ~1min integration test of the core Panic engine")
      Panic.Engine.start_run!(invocation, actor: user)
      Process.sleep(5_000)

      IO.write("check that new runs *can't* be triggered within 30s of run start...")

      too_early_invocation =
        network
        |> Panic.Engine.prepare_first!("ok, tell me another one", actor: user)

      {:error, _} = Panic.Engine.start_run(too_early_invocation, actor: user)
      refute_enqueued(args: %{"invocation_id" => too_early_invocation.id})
      IO.puts("done")

      Process.sleep(30_000)

      IO.write("check that new runs *can* be triggered more than 30s from run start...")

      timely_invocation =
        network
        |> Panic.Engine.prepare_first!("ok, tell me a third story, different from the first two",
          actor: user
        )

      Panic.Engine.start_run!(timely_invocation, actor: user)
      assert_enqueued(args: %{"invocation_id" => timely_invocation.id})

      Process.sleep(30_000)
      IO.puts("done")

      IO.write("stop the run and check everything worked correctly...")
      Panic.Engine.stop_run!(network.id, actor: user)

      assert [] = all_enqueued()

      invocations =
        Panic.Engine.list_run!(network.id, invocation.run_number, actor: user)

      IO.puts("done (#{length(invocations)} created)")

      # check some invariants
      invocations
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [a, b] ->
        assert a.output == b.input
        assert a.sequence_number == b.sequence_number - 1
        assert a.run_number == invocation.run_number
        assert a.network_id == invocation.network_id
      end)

      assert {:ok, %Panic.Engine.Invocation{output: nil}} =
               Ash.get(Panic.Engine.Invocation, too_early_invocation.id, actor: user)

      assert {:ok, %Panic.Engine.Invocation{output: output}} =
               Ash.get(Panic.Engine.Invocation, timely_invocation.id, actor: user)

      assert is_binary(output) and output != ""
    end
  end
end
