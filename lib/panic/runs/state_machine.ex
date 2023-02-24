defmodule Panic.Runs.StateMachine do
  @moduledoc """
  A Finite State Machine (FSM) to manage a Panic! run

  """

  @fsm """
  initial --> |init!| waiting

  waiting --> |new_prediction| waiting
  waiting --> |new_prediction| running_startup
  waiting --> |lock| locked
  waiting --> |reset| waiting
  waiting --> |shut_down| final

  running_startup --> |new_prediction| running_startup
  running_startup --> |new_prediction| running_ready
  running_startup --> |reset| waiting
  running_startup --> |lock| locked
  running_startup --> |shut_down| final

  running_ready --> |new_prediction| running_ready
  running_ready --> |reset| waiting
  running_ready --> |lock| locked
  running_ready --> |shut_down| final

  locked --> |new_prediction| locked
  locked --> |unlock| waiting
  locked --> |reset| waiting
  locked --> |shut_down| final
  """

  use Finitomata, fsm: @fsm, auto_terminate: true
  alias Panic.{Networks, Predictions}
  alias Panic.Predictions.Prediction

  require Logger

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
  def on_transition(state, :reset, _event_payload, payload) do
    reset_payload(payload)
  end

  # genesis prediction handler
  @impl Finitomata
  def on_transition(state, :new_prediction, %Prediction{run_index: 0} = new_prediction, payload)
      when state in [:waiting, :running_ready] do
    Networks.broadcast(new_prediction.network.id, {:new_prediction, new_prediction})

    Predictions.create_prediction_async(
      new_prediction,
      payload.tokens,
      fn prediction ->
        Finitomata.transition(prediction.network.id, {:new_prediction, prediction})
      end
    )

    {:ok, next_state(state),
     %{payload | genesis_prediction: new_prediction, head_prediction: new_prediction}}
  end

  # next run prediction handler. this approach - trying to do it all in the
  # guard clauses - might be a code smell? maybe I can write a new guard?
  @impl Finitomata
  def on_transition(
        state,
        :new_prediction,
        %Prediction{run_index: new_index} = new_prediction,
        %{head_prediction: %Prediction{run_index: head_index}} = payload
      )
      when state in [:running_startup, :running_ready] and new_index == head_index + 1 do

    Networks.broadcast(new_prediction.network.id, {:new_prediction, new_prediction})

    Predictions.create_prediction_async(new_prediction, payload.tokens, fn prediction ->
      Finitomata.transition(prediction.network.id, {:new_prediction, prediction})
    end)

    {:ok, next_state(state, payload), %{payload | head_prediction: new_prediction}}
  end

  # orphan prediction handler
  @impl Finitomata
  def on_transition(state, :new_prediction, %Prediction{} = new_prediction, payload) do
    {:ok, %Prediction{}} = Predictions.delete_prediction(new_prediction)
    {:ok, state, payload}
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

  ####################
  # helper functions #
  ####################

  ## because we've coalesced a couple of from->to transitions in the
  ## :new_prediction handlers, it's useful to have these functions
  defp next_state(:waiting), do: :running_startup
  defp next_state(:running_ready), do: :running_ready

  defp next_state(_state, payload) do
    if seconds_since_prediction(payload.genesis_prediction) > 30 do
      :running_ready
    else
      :running_startup
    end
  end

  defp seconds_since_prediction(%Prediction{inserted_at: inserted_at}),
    do: NaiveDateTime.utc_now() |> NaiveDateTime.diff(inserted_at, :second)

  defp reset_payload(payload) do
    {:ok, :waiting,
     payload
     |> Map.put(:genesis_prediction, nil)
     ## the "head" prediction is the most recent prediction in the current run
     ## (it's sortof the opposite of the genesis prediction)
     |> Map.put(:head_prediction, nil)}
  end

  # defp debug_helper(label, state, prediction) do
  #   Logger.debug(
  #     "#{label}: (#{state}) #{prediction.id}-#{prediction.run_index}-#{prediction.genesis_id} #{prediction.input}"
  #   )
  # end

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
