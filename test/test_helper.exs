ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Panic.Repo, :manual)

defmodule Panic.Generators do
  @moduledoc """
  StreamData generators for Panic resources.
  """
  use ExUnitProperties

  def network do
    gen all(
          input <-
            Ash.Generator.action_input(Panic.Engine.Network, :create, %{
              models:
                list_of(
                  StreamData.member_of([
                    Panic.Models.SDXL,
                    Panic.Models.BLIP2,
                    Panic.Models.GPT4o
                  ])
                )
            })
        ) do
      Panic.Engine.Network
      |> Ash.Changeset.for_create(:create, input)
      |> Ash.create!()
    end
  end
end
