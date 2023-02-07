defmodule Panic.Runs.RunFSM do
  @moduledoc """
  A Finite State Machine (FSM) to manage a Panic! run

  """

  @fsm """
  pre_run --> |init!| waiting
  waiting --> |new_prediction| waiting
  waiting --> |new_prediction| running
  running --> |new_prediction| running
  running --> |reset| waiting
  waiting --> |lock| locked
  running --> |lock| locked
  locked -->  |unlock| running
  waiting --> |shut_down| post_run
  running --> |shut_down| post_run
  """

  use Finitomata, fsm: @fsm, auto_terminate: true
  alias Panic.Predictions
  alias Panic.Predictions.Prediction

  @doc "return the FSM (in Mermaid syntax)"
  def fsm_description do
    @fsm
  end

  @impl Finitomata
  def on_transition(:pre_run, :init!, _event_payload, payload) do
    reset_payload(payload)
  end

  @impl Finitomata
  def on_transition(_state, :unlock, _prev_state, payload) do
    ## TODO figure out how to re-start the run if prev_state == :running
    reset_payload(payload)
  end

  @impl Finitomata
  def on_transition(_state, :reset, _event_payload, payload) do
    IO.puts("reset: in on_transition")
    reset_payload(payload)
  end

  @impl Finitomata
  def on_transition(
        state,
        :new_prediction,
        %Prediction{} = new_prediction,
        %{network: network} = payload
      )
      when state in [:waiting, :running] do
    cond do
      ## a new genesis prediction
      new_prediction.run_index == 0 and NaiveDateTime.compare(now(), payload.lockout_time) == :gt ->
        debug_helper("genesis", state, new_prediction)
        create_new_prediction_async(new_prediction, network)

        {:ok, :running, %{payload | head_prediction: new_prediction, lockout_time: from_now(30)}}

      ## continuing on with things
      next_in_run?(new_prediction, payload.head_prediction) ->
        debug_helper("next", state, new_prediction)
        create_new_prediction_async(new_prediction, network)

        {:ok, :running, %{payload | head_prediction: new_prediction}}

      ## otherwise, ignore and delete orphaned prediction
      true ->
        debug_helper("orphan", state, new_prediction)
        {:ok, %Prediction{}} = Predictions.delete_prediction(new_prediction)
        {:ok, state, payload}
    end
  end

  @impl Finitomata
  def on_transition(state, :lock, duration_in_seconds, payload) do
    Finitomata.transition(payload.network.id, {:unlock, state}, duration_in_seconds * 1000)
    {:ok, :locked, payload}
  end

  defp create_new_prediction_async(%Prediction{} = new_prediction, network) do
    Task.Supervisor.start_child(
      Panic.Platforms.TaskSupervisor,
      fn ->
        {:ok, next_prediction} = Predictions.create_next_prediction(new_prediction, network)
        Finitomata.transition(network.id, {:new_prediction, next_prediction})
      end,
      restart: :transient
    )
  end

  defp now(), do: NaiveDateTime.utc_now()

  defp from_now(amount_to_add, unit \\ :second),
    do: NaiveDateTime.utc_now() |> NaiveDateTime.add(amount_to_add, unit)

  defp next_in_run?(%Prediction{run_index: 0}, nil), do: true

  defp next_in_run?(%Prediction{run_index: new_index}, %Prediction{run_index: head_index}) do
    new_index == head_index + 1
  end

  defp next_in_run?(_new_prediction, _head_prediction), do: false

  defp reset_payload(payload) do
    {:ok, :waiting,
     payload
     ## the "head" prediction is the most recent prediction in the current run
     ## (it's sortof the opposite of the genesis prediction)
     |> Map.put(:head_prediction, nil)
     ## make sure this is in the past
     |> Map.put(:lockout_time, from_now(-1, :day))}
  end

  defp debug_helper(label, state, prediction) do
    IO.puts(
      "#{label}: (#{state}) #{prediction.id}-#{prediction.run_index}-#{prediction.genesis_id} #{prediction.input}"
    )
  end
end
