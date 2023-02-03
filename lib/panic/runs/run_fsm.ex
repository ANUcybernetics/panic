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
     |> Map.put(:lockout_time, NaiveDateTime.utc_now())
     |> Map.put(:latest_input, nil)}
  end

  @impl Finitomata
  def on_transition(_state, :reset, _event_payload, payload) do
    {:ok, :waiting, %{payload | lockout_time: NaiveDateTime.utc_now(), latest_input: nil}}
  end

  @impl Finitomata
  def on_transition(state, :input, input, payload) do
    if locked_out_now?(payload.lockout_time) do
      IO.inspect("locked out, dropping input: #{input}")

      {:ok, state, payload}
    else
      {:ok, prediction} =
        case payload.latest_input do
          nil ->
            IO.inspect({input, payload.network})
            Predictions.create_genesis_prediction(input, payload.network)

          %Prediction{} = previous_prediction ->
            Predictions.create_next_prediction(previous_prediction, payload.network)
        end

      IO.inspect("pre-message")
      Finitomata.transition("network:#{payload.network.id}", {:input, prediction.output})
      IO.inspect("post-message")

      if state == :waiting do
        {:ok, state,
         %{
           payload
           | lockout_time: NaiveDateTime.utc_now() |> NaiveDateTime.add(30),
             latest_input: prediction
         }}
      else
        {:ok, state, %{payload | latest_input: prediction}}
      end
    end
  end

  defp locked_out_now?(lockout_time) do
    lockout_time > NaiveDateTime.utc_now()
  end
end
