defmodule Panic.Engine.Actions.RunFootprint do
  @moduledoc """
  The estimated cost and energy of a run's invocations so far (see
  `Panic.Engine.Footprint`). Invocations from before the estimates were
  recorded count as nothing.
  """
  use Ash.Resource.Actions.Implementation

  alias Panic.Engine.Invocation

  require Ash.Query

  @impl true
  def run(input, _opts, _context) do
    run_number = input.arguments.run_number

    Invocation
    |> Ash.Query.filter(run_number == ^run_number)
    |> Ash.aggregate([{:cost_usd, :sum, field: :cost_usd}, {:energy_wh, :sum, field: :energy_wh}],
      authorize?: false
    )
  end
end
