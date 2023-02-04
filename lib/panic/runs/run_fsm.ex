defmodule Panic.Runs.RunFSM do
  @moduledoc """
  A Finite State Machine (FSM) to manage a Panic! run

  """

  @fsm """
  pre_run --> |init!| waiting
  waiting --> |input| running
  running --> |input| running
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

  @impl Finitomata
  def on_transition(:pre_run, :init!, _event_payload, payload) do
    {:ok, :waiting, Map.put(payload, :last_input, nil)}
  end

  @impl Finitomata
  def on_transition(state, :input, input, %{network: network} = payload) do
    ## first 10 cycles is the "lockout period"
    if next_in_run?(input, payload.last_input) do
      Task.Supervisor.start_child(
        Panic.Platforms.TaskSupervisor,
        fn ->
          {:ok, prediction} =
            case input do
              input when is_binary(input) ->
                Predictions.create_genesis_prediction(input, network)

              %Prediction{} = previous_prediction ->
                Predictions.create_next_prediction(previous_prediction, network)
            end

          Finitomata.transition(network.id, {:input, prediction})
        end,
        restart: :transient
      )

      {:ok, :running, %{payload | last_input: input}}
    else
      {:ok, state, payload}
    end
  end

  @impl Finitomata
  def on_transition(state, :lock, duration_in_seconds, payload) do
    Finitomata.transition(payload.network.id, {:unlock, state}, duration_in_seconds * 1000)
    {:ok, :locked, payload}
  end

  @impl Finitomata
  def on_transition(_state, :unlock, _prev_state, payload) do
    ## TODO figure out how to re-start the run if prev_state == :running
    {:ok, :waiting, payload}
  end

  @impl Finitomata
  def on_transition(_state, :reset, _event_payload, payload) do
    {:ok, :waiting, payload}
  end

  defp next_in_run?(input, last_input) do
    case {input, last_input} do
      {input, nil} when is_binary(input) -> true
      {%Prediction{run_index: 0}, <<>>} -> true
      {%Prediction{run_index: current}, %Prediction{run_index: last}} -> current == last + 1
      _ -> false
    end
  end
end
