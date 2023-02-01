defmodule Panic.Runs.RunFSM do
  @moduledoc """
  A Finite State Machine (FSM) to manage a Panic! run

  """

  @fsm """
  pre_run --> |init!| waiting
  waiting --> |prediction| running
  running --> |prediction| running
  running --> |stop| waiting
  running --> |reset| waiting
  waiting --> |end_run| post_run
  running --> |end_run| post_run
  """

  use Finitomata, fsm: @fsm, auto_terminate: true
  alias Panic.Predictions

  @impl Finitomata
  def on_transition(:pre_run, :init!, _event_payload, payload) do
    {:ok, :waiting, payload}
  end

  @impl Finitomata
  def on_transition(:waiting, :prediction, prediction, payload) do
    {:ok, :running, Map.put(payload, :last_prediction, prediction)}
  end

  @impl Finitomata
  def on_enter(:running, %Finitomata.State{
        payload: %{last_prediction: last_prediction, network: network}
      }) do
    IO.inspect("entering :running state, last prediction id was #{last_prediction.id}")
    Process.sleep(1_000)
    Finitomata.transition("network:#{network.id}", {:prediction, Enum.random(0..100)})
    :ok
  end
end
