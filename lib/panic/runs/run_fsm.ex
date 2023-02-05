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

  @lockout_seconds 30

  @impl Finitomata
  def on_transition(:pre_run, :init!, _event_payload, payload) do
    {:ok, :waiting,
     payload
     |> Map.put(:last_input, nil)
     ## make sure this is in the past
     |> Map.put(:lockout_time, later(-1, :day))}
  end

  @impl Finitomata
  def on_transition(state, :input, input, %{network: network} = payload) do
    ## first 10 cycles is the "lockout period"
    if accept_new_input?(input, payload) do
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

      if state == :waiting do
        IO.puts("setting lockout time 30s into the future")
        {:ok, :running, %{payload | last_input: input, lockout_time: later(@lockout_seconds)}}
      else
        {:ok, :running, %{payload | last_input: input}}
      end
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
    {:ok, :waiting,
     payload
     |> Map.put(:last_input, nil)
     ## make sure this is in the past
     |> Map.put(:lockout_time, later(-1, :day))}
  end

  defp next_in_run?(input, last_input) do
    case {input, last_input} do
      {input, nil} when is_binary(input) -> true
      {%Prediction{run_index: 0}, <<>>} -> true
      {%Prediction{run_index: current}, %Prediction{run_index: last}} -> current == last + 1
      _ -> false
    end
  end

  defp accept_new_input?(input, payload) do
    cond do
      next_in_run?(input, payload.last_input) -> true
      is_binary(input) -> now() > payload.lockout_time
      true -> false
    end
  end

  defp now(), do: NaiveDateTime.utc_now()

  defp later(amount_to_add, unit \\ :second),
    do: NaiveDateTime.utc_now() |> NaiveDateTime.add(amount_to_add, unit)
end
