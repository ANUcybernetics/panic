defmodule Panic.ObanTest do
  use Panic.DataCase
  use ExUnitProperties
  # alias Panic.Engine.Invocation

  describe "Invocation Oban Jobs" do
    @describetag skip: "requires API keys"

    test "invocation can be queued" do
      user = Panic.Fixtures.user()

      check all(
              network <- Panic.Generators.network_with_models(user),
              input <- Panic.Generators.ascii_sentence()
            ) do
        invocation = Panic.Engine.prepare_first!(network, input, actor: user)
        invoked = Panic.Engine.invoke!(invocation, actor: user)
        # TODO Oban query goes here
        refute invoked.output == nil
      end
    end
  end
end
