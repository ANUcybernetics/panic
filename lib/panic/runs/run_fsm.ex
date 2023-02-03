defmodule Panic.Runs.RunFSM do
  @moduledoc """
  A Finite State Machine (FSM) to manage a Panic! run

  """

  @fsm """
  pre_run --> |init!| waiting
  waiting --> |input| running
  running --> |input| running
  waiting --> |pause| waiting
  running --> |pause| waiting
  waiting --> |reset| waiting
  running --> |reset| waiting
  waiting --> |shut_down| post_run
  running --> |shut_down| post_run
  """

  use Finitomata, fsm: @fsm, auto_terminate: true
  alias Panic.Predictions
  alias Panic.Predictions.Prediction

  @impl Finitomata
  def on_transition(:pre_run, :init!, _event_payload, payload) do
    {:ok, :waiting,
     payload
     # this needs to be *well* in the past (because clocks might not be synced between processes)
     |> Map.put(:lockout_time, NaiveDateTime.add(NaiveDateTime.utc_now(), -1, :day))}
  end

  @impl Finitomata
  def on_transition(_state, :reset, _event_payload, payload) do
    {:ok, :waiting, %{payload | lockout_time: NaiveDateTime.utc_now()}}
  end

  @impl Finitomata
  def on_transition(state, :input, input, %{network: network} = payload) do
    if locked_out?(input, payload) do
      {:ok, state, payload}
    else
      _task =
        Task.Supervisor.start_child(Panic.Platforms.TaskSupervisor, fn ->
          {:ok, prediction} =
            case input do
              input when is_binary(input) ->
                Predictions.create_genesis_prediction(input, network)

              %Prediction{} = previous_prediction ->
                Predictions.create_next_prediction(previous_prediction, network)
            end

          Finitomata.transition(network.id, {:input, prediction})
        end)

      if state == :waiting do
        {:ok, :running,
         %{payload | lockout_time: NaiveDateTime.utc_now() |> NaiveDateTime.add(30)}}
      else
        {:ok, :running, payload}
      end
    end
  end

  defp locked_out?(%Prediction{run_index: 0}, %{lockout_time: lockout_time}) do
    NaiveDateTime.utc_now() < lockout_time
  end

  defp locked_out?(_input, _payload), do: false
end
