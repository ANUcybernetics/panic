defmodule Panic.Runs.StateMachine do
  @moduledoc """
  A Finite State Machine (FSM) to manage a Panic! run

  """

  @fsm """
  initial --> |init!| waiting

  waiting --> |new_prediction| waiting
  waiting --> |new_prediction| running_startup
  waiting --> |lock| locked
  waiting --> |shut_down| final

  running_startup --> |new_prediction| running_startup
  running_startup --> |stop| waiting
  running_startup --> |lock| locked
  running_startup --> |shut_down| final
  running_startup --> |startup_ended| running_ready

  running_ready --> |new_prediction| running_ready
  running_ready --> |stop| waiting
  running_ready --> |lock| locked
  running_ready --> |shut_down| final

  locked --> |new_prediction| locked
  locked --> |unlock| waiting
  locked --> |shut_down| final
  """

  use Finitomata, fsm: @fsm, auto_terminate: true
  alias Panic.{Networks, Predictions}
  alias Panic.Predictions.Prediction

  require Logger

  @startup_duration 30_000

  @doc "return the FSM (in Mermaid syntax)"
  def fsm_description do
    @fsm
  end

  @impl Finitomata
  def on_transition(:initial, :init!, _event_payload, payload) do
    reset_payload(payload)
  end

  @impl Finitomata
  def on_transition(_state, :unlock, _prev_state, payload) do
    ## TODO figure out how to re-start the run if prev_state == :running
    reset_payload(payload)
  end

  @impl Finitomata
  def on_transition(state, :stop, _event_payload, payload) do
    Logger.info(":stop (in #{state})")
    reset_payload(payload)
  end

  # TODO refactor this into a private helper fn for each clause in the `cond do`
  @impl Finitomata
  def on_transition(state, :new_prediction, %Prediction{} = new_prediction, payload)
      when state in [:waiting, :running_startup, :running_ready] do
    cond do
      ## a new genesis prediction
      new_prediction.run_index == 0 and state in [:waiting, :running_ready] ->
        debug_helper("genesis", state, new_prediction)

        Predictions.create_prediction_async(
          new_prediction,
          payload.tokens,
          fn prediction ->
            Finitomata.transition(prediction.network.id, {:new_prediction, prediction})
            Networks.broadcast(prediction.network.id, {:new_prediction, prediction})
          end
        )

        Finitomata.transition(payload.network.id, {:startup_ended, nil}, @startup_duration)

        {:ok, :running_startup,
         %{payload | genesis_prediction: new_prediction, head_prediction: new_prediction}}

      ## continuing on with things
      next_in_run?(new_prediction, payload.head_prediction) ->
        debug_helper("next", state, new_prediction)

        Predictions.create_prediction_async(new_prediction, payload.tokens, fn prediction ->
          Finitomata.transition(prediction.network.id, {:new_prediction, prediction})
          Networks.broadcast(prediction.network.id, {:new_prediction, prediction})
        end)

        {:ok, state, %{payload | head_prediction: new_prediction}}

      ## otherwise, ignore and delete orphaned prediction
      true ->
        debug_helper("orphan", state, new_prediction)
        {:ok, %Prediction{}} = Predictions.delete_prediction(new_prediction)
        {:ok, state, payload}
    end
  end

  @impl Finitomata
  def on_transition(:locked, :new_prediction, %Prediction{} = new_prediction, payload) do
    {:ok, %Prediction{}} = Predictions.delete_prediction(new_prediction)
    {:ok, :locked, payload}
  end

  @impl Finitomata
  def on_transition(state, :lock, duration_in_seconds, payload) do
    Finitomata.transition(payload.network.id, {:unlock, state}, duration_in_seconds * 1000)
    {:ok, :locked, payload}
  end

  @impl Finitomata
  def on_enter(state, %Finitomata.State{payload: %{network: network}}) do
    Networks.broadcast(network.id, {:state_change, state})
    :ok
  end

  defp next_in_run?(%Prediction{run_index: 0}, nil), do: true

  defp next_in_run?(%Prediction{run_index: new_index}, %Prediction{run_index: head_index}) do
    new_index == head_index + 1
  end

  defp next_in_run?(_new_prediction, _head_prediction), do: false

  ## TODO to avoid confusion with actual "locked" state, perhaps change
  ## lockout_time to debounce_time?
  defp reset_payload(payload) do
    {:ok, :waiting,
     payload
     |> Map.put(:genesis_prediction, nil)
     ## the "head" prediction is the most recent prediction in the current run
     ## (it's sortof the opposite of the genesis prediction)
     |> Map.put(:head_prediction, nil)}
  end

  defp debug_helper(label, state, prediction) do
    Logger.info(
      "#{label}: (#{state}) #{prediction.id}-#{prediction.run_index}-#{prediction.genesis_id} #{prediction.input}"
    )
  end

  # helper functions - some just pass the args through to the appropriate
  # Finitomata function, but this way it'll be easier to use a different FSM lib
  # in future

  def current_state(network_id) do
    network_id
    |> Finitomata.state()
    |> Map.get(:current)
  end

  # this is just a passthrough, but it's handyd
  def transition(network_id, event_payload, delay \\ 0) do
    Finitomata.transition(network_id, event_payload, delay)
  end

  def alive?(network_id) do
    Finitomata.alive?(network_id)
  end

  def start_if_not_running(network) do
    unless alive?(network.id) do
      Finitomata.start_fsm(Panic.Runs.StateMachine, network.id, %{
        network: network,
        tokens: Panic.Accounts.get_api_token_map(network.user_id)
      })
    end
  end
end
