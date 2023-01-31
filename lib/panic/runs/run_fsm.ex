defmodule Panic.Runs.RunFSM do
  @moduledoc """
  A Finite State Machine (FSM) to manage a Panic! run

  """

  @fsm """
  pre_run --> |init!| waiting
  waiting --> |input| running
  running --> |prediction| running
  running --> |input| running
  running --> |stop| waiting
  running --> |reset| waiting
  waiting --> |end_run| post_run
  running --> |end_run| post_run
  """

  use Finitomata, fsm: @fsm, auto_terminate: true

  @impl Finitomata
  def on_transition(:pre_run, :init!, _event_payload, payload) do
    {:ok, :waiting, payload}
  end

  @impl Finitomata
  def on_transition(:waiting, :input, changeset, payload) do
    ## TODO fire off API call to hosted AI platform
    {:ok, :running, Map.merge(payload, changeset: changeset)}
  end

  @impl Finitomata
  def on_transition(:running, :prediction, _prediction, payload) do
    {:ok, :running, Map.merge(payload, :ready_countdown)}
  end
end
