defmodule Panic.Runs.RunFSM do
  @moduledoc """
  A Finite State Machine (FSM) to manage a Panic! run

  """

  @fsm """
  pre_run --> |init!| waiting
  waiting --> |prediction| running
  running --> |prediction| running
  running --> |reset| waiting
  waiting --> |end_run| post_run
  running --> |pause| post_run
  waiting --> |pause| post_run
  """

  use Finitomata, fsm: @fsm, auto_terminate: true
  alias Panic.Predictions
  alias Panic.Predictions.Prediction

  @impl Finitomata
  def on_transition(:pre_run, :init!, _event_payload, payload) do
    payload =
      payload
      |> Map.put(:last_prediction, nil)
      |> Map.put(:lockout_time, NaiveDateTime.utc_now())

    {:ok, :waiting, payload}
  end

  @impl Finitomata
  def on_transition(:running, :reset, _event_payload, payload) do
    {:ok, :waiting, %{payload | last_prediction: nil, lockout_time: NaiveDateTime.utc_now()}}
  end

  @impl Finitomata
  def on_transition(:waiting, :prediction, prediction, payload) do
    payload =
      payload
      |> Map.put(:last_prediction, prediction)
      |> Map.put(:lockout_time, NaiveDateTime.utc_now() |> NaiveDateTime.add(30, :second))

    {:ok, :running, payload}
  end

  @impl Finitomata
  def on_transition(:running, :prediction, prediction, payload) do
    case {prediction, NaiveDateTime.utc_now()} do
      {%Prediction{run_index: 0}, now} when now > payload.lockout_time ->
        {:ok, :running, %{payload | last_prediction: prediction}}

      _ ->
        {:ok, :running, payload}
    end
  end

  @impl Finitomata
  def on_enter(:running, %Finitomata.State{
        payload: %{last_prediction: last_prediction, network: network}
      }) do
    {:ok, prediction} = Predictions.create_next_prediction(last_prediction)
    IO.inspect("API call goes here, current run index #{last_prediction.run_index + 1}")
    Process.sleep(1_000)
    Finitomata.transition("network:#{network.id}", {:prediction, prediction})

    :ok
  end
end
