defmodule Panic.ObanTest do
  use Panic.DataCase
  use ExUnitProperties
  use Oban.Testing, repo: Panic.Repo
  # alias Panic.Engine.Invocation

  describe "Oban-powered Panic.Workers.Invoker" do
    # @describetag skip: "requires API keys"

    test "can be successfully started, run for 30s and stopped" do
      IO.write("about to run a 30s test of the Oban prepare-and-invoke process...")
      user = Panic.Fixtures.user_with_tokens()
      network = Panic.Fixtures.network_with_models(user)
      input = "can you tell me a story?"

      invocation =
        network
        |> Panic.Engine.prepare_first!(input, actor: user)

      Panic.Engine.start_run!(invocation, actor: user)
      Process.sleep(30_000)
      Panic.Engine.stop_run!(network.id, actor: user)

      invocations =
        Panic.Engine.list_run!(network.id, invocation.run_number, actor: user)

      # check some invariants
      invocations
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [a, b] ->
        assert a.output == b.input
        assert a.sequence_number == b.sequence_number - 1
        assert a.run_number == invocation.run_number
        assert a.network_id == invocation.network_id
      end)

      IO.puts("done (#{length(invocations)} created)")
    end
  end
end
