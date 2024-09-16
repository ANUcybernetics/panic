defmodule Panic.ObanTest do
  use Panic.DataCase
  use ExUnitProperties
  use Oban.Testing, repo: Panic.Repo
  # alias Panic.Engine.Invocation

  describe "Panic.Workers.Invoker" do
    @describetag skip: "requires API keys"

    test "can be successfully triggered via :start_run Network action" do
      user = Panic.Fixtures.user_with_tokens()
      network = Panic.Fixtures.network_with_models(user)
      input = "can you tell me a story?"

      invocation =
        network
        |> Panic.Engine.prepare_first!(input, actor: user)

      Panic.Engine.start_run!(invocation, actor: user)

      assert_enqueued(
        worker: Panic.Workers.Invoker,
        args: %{
          "invocation_id" => invocation.id,
          "network_id" => network.id,
          "sequence_number" => 0
        }
      )
    end
  end
end
