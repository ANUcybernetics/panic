defmodule Panic.ObanTest do
  use Panic.DataCase
  use ExUnitProperties
  use Oban.Testing, repo: Panic.Repo
  # alias Panic.Engine.Invocation

  describe "Panic.Workers.Invoker" do
    # @describetag skip: "requires API keys"

    test "can be successfully triggered via :start_run Network action" do
      user = Panic.Fixtures.user_with_tokens()
      network = Panic.Fixtures.network_with_models(user)
      input = "can you tell me a story?"

      invocation =
        network
        |> Panic.Engine.prepare_first!(input, actor: user)

      Panic.Engine.start_run!(invocation, actor: user)
      Process.sleep(15_000)
      Panic.Engine.stop_run!(network.id, actor: user)

      [first, second | _rest] =
        Panic.Engine.all_in_run!(network.id, invocation.run_number, actor: user)

      assert Ash.load(first, :network, actor: user) == invocation
      assert second.run_number == invocation.run_number
      assert second.sequence_number == 1
    end
  end
end
