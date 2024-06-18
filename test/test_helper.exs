ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Panic.Repo, :manual)

defmodule Panic.Generators do
  @moduledoc """
  StreamData generators for Panic resources.
  """
  use ExUnitProperties

  def network(opts \\ []) do
    gen all(
          input <-
            Ash.Generator.action_input(Panic.Engine.Network, :create, %{
              models:
                list_of(
                  StreamData.member_of([
                    Panic.Models.SDXL,
                    Panic.Models.BLIP2,
                    Panic.Models.GPT4o
                  ]),
                  opts
                )
            })
        ) do
      Panic.Engine.Network
      |> Ash.Changeset.for_create(:create, input)
      |> Ash.create!()
    end
  end

  def invocation do
    gen all(
          input <-
            Ash.Generator.action_input(Panic.Engine.Invocation, :create_first, %{
              # need at least one, otherwise Panic.Changes.Invoke will raise
              network: network(min_length: 1)
            })
        ) do
      Panic.Engine.Invocation
      |> Ash.Changeset.for_create(:create_first, input)
      |> Ash.create!()
    end
  end
end
