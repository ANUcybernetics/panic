defmodule PanicWeb.NetworkLive.RunSummary do
  @moduledoc """
  What a terminal shows of a run: how far it's got, its latest text and image
  outputs (what the Vestaboards and screens are showing, give or take a
  Vestaboard's hold) and its estimated cost and energy so far (see
  `Panic.Engine.Footprint`).
  """
  alias Panic.Engine.Invocation

  require Ash.Query

  defstruct [:run_number, :sequence_number, :text, :image, cost_usd: 0.0, energy_wh: 0.0]

  @type t :: %__MODULE__{
          run_number: integer(),
          sequence_number: non_neg_integer(),
          text: String.t() | nil,
          image: String.t() | nil,
          cost_usd: float(),
          energy_wh: float()
        }

  @doc """
  The summary of run `run_number` (nil for no run). A network's models take
  turns, so the latest outputs are among its last two rounds of invocations.
  """
  @spec load(integer() | nil, [String.t()]) :: t() | nil
  def load(nil, _models), do: nil

  def load(run_number, models) do
    recent =
      Invocation
      |> Ash.Query.filter(run_number == ^run_number)
      |> Ash.Query.sort(sequence_number: :desc)
      |> Ash.Query.limit(2 * length(models) + 1)
      |> Ash.read!(authorize?: false)

    footprint = Panic.Engine.run_footprint!(run_number)

    %__MODULE__{
      run_number: run_number,
      sequence_number: recent |> Enum.map(& &1.sequence_number) |> Enum.max(fn -> 0 end),
      text: latest_output(recent, :text),
      image: latest_output(recent, :image),
      cost_usd: footprint.cost_usd || 0.0,
      energy_wh: footprint.energy_wh || 0.0
    }
  end

  @doc """
  The summary after a broadcast of `invocation`: a completed invocation (or a
  newer run) is reloaded, an invocation starting moves the sequence number on,
  and a straggler from an earlier run is ignored.
  """
  @spec update(t() | nil, Invocation.t(), [String.t()]) :: t() | nil
  def update(%__MODULE__{run_number: run} = summary, %Invocation{run_number: other}, _models) when other < run,
    do: summary

  def update(%__MODULE__{run_number: run} = summary, %Invocation{run_number: run, state: state} = invocation, _models)
      when state != :completed, do: %{summary | sequence_number: max(summary.sequence_number, invocation.sequence_number)}

  def update(_summary, %Invocation{run_number: run_number}, models), do: load(run_number, models)

  defp latest_output(invocations, type) do
    Enum.find_value(invocations, fn invocation ->
      with %Invocation{state: :completed, output: output} when is_binary(output) <- invocation,
           %Panic.Model{output_type: ^type} <- Panic.Model.by_id(invocation.model) do
        output
      else
        _ -> nil
      end
    end)
  end
end
