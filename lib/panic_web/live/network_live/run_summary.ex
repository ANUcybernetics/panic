defmodule PanicWeb.NetworkLive.RunSummary do
  @moduledoc """
  What terminals and an installation's first screen show of a run: its prompt,
  when it started, how far it's got, which model is at work (or when the next
  one starts, while it waits), and its estimated cost and energy so far (see
  `Panic.Engine.Footprint`).
  """
  alias Panic.Engine.Invocation

  defstruct [
    :run_number,
    :prompt,
    :started_at,
    :sequence_number,
    :model,
    :next_at,
    cost_usd: 0.0,
    energy_wh: 0.0
  ]

  @type t :: %__MODULE__{
          run_number: integer(),
          prompt: String.t(),
          started_at: DateTime.t(),
          sequence_number: non_neg_integer(),
          model: String.t(),
          next_at: DateTime.t() | nil,
          cost_usd: float(),
          energy_wh: float()
        }

  @doc """
  The summary of run `run_number` (nil for no run).
  """
  @spec load(integer() | nil) :: t() | nil
  def load(nil), do: nil

  def load(run_number) do
    # the run number is the genesis invocation's id
    genesis = Panic.Engine.get_invocation!(run_number, authorize?: false)

    head =
      [
        query: [filter: [run_number: run_number], sort: [sequence_number: :desc], limit: 1],
        authorize?: false
      ]
      |> Panic.Engine.list_invocations!()
      |> List.first(genesis)

    footprint = Panic.Engine.run_footprint!(run_number)

    %__MODULE__{
      run_number: run_number,
      prompt: genesis.input,
      started_at: genesis.inserted_at,
      sequence_number: head.sequence_number,
      model: model_name(head),
      next_at: next_at(head),
      cost_usd: footprint.cost_usd || 0.0,
      energy_wh: footprint.energy_wh || 0.0
    }
  end

  @doc """
  The summary after a broadcast of `invocation`: a completed invocation (or a
  newer run) is reloaded, an invocation starting moves the sequence number and model on,
  and a straggler from an earlier run is ignored.
  """
  @spec update(t() | nil, Invocation.t()) :: t() | nil
  def update(%__MODULE__{run_number: run} = summary, %Invocation{run_number: other}) when other < run, do: summary

  def update(%__MODULE__{run_number: run} = summary, %Invocation{run_number: run, state: state} = invocation)
      when state != :completed do
    if invocation.sequence_number >= summary.sequence_number,
      do: %{
        summary
        | sequence_number: invocation.sequence_number,
          model: model_name(invocation),
          next_at: next_at(invocation)
      },
      else: summary
  end

  def update(_summary, %Invocation{run_number: run_number}), do: load(run_number)

  # when the run's latest invocation is due, or nil once it's under way
  defp next_at(%Invocation{state: :ready, invoke_after: invoke_after}), do: invoke_after
  defp next_at(_invocation), do: nil

  defp model_name(%Invocation{model: id}) do
    case Panic.Model.by_id(id) do
      %Panic.Model{name: name} -> name
      nil -> id
    end
  end
end
