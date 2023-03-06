defmodule Panic.Runs.StateMachine do
  @moduledoc """
  A Finite State Machine (FSM) to manage a Panic! run

  """

  @fsm """
  initial --> |init!| ready

  ready --> |genesis_input| running_genesis
  ready --> |new_prediction| ready
  ready --> |reset| ready
  ready --> |lock| locked
  ready --> |shut_down| final

  running_genesis --> |new_prediction| uninterruptable
  running_genesis --> |new_prediction| running_genesis
  running_genesis --> |reset| ready
  running_genesis --> |lock| locked
  running_genesis --> |shut_down| final

  uninterruptable --> |new_prediction| uninterruptable
  uninterruptable --> |new_prediction| interruptable
  uninterruptable --> |reset| ready
  uninterruptable --> |lock| locked
  uninterruptable --> |shut_down| final

  interruptable --> |genesis_input| running_genesis
  interruptable --> |new_prediction| interruptable
  interruptable --> |reset| ready
  interruptable --> |lock| locked
  interruptable --> |shut_down| final

  locked --> |running_genesis| locked
  locked --> |new_prediction| locked
  locked --> |unlock| ready
  locked --> |reset| ready
  locked --> |shut_down| final
  """

  use Finitomata, fsm: @fsm, auto_terminate: true
  alias Panic.{Networks, Predictions}
  alias Panic.Networks.Network
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
  def on_transition(_state, :genesis_input, input, payload) do
    Task.Supervisor.start_child(
      Panic.Runs.TaskSupervisor,
      Panic.Runs.StateMachine,
      :create_prediction_and_transition,
      [input, payload.network, payload.tokens],
      restart: :transient
    )

    {:ok, :running_genesis, %{payload | genesis_prediction: nil, head_prediction: nil}}
  end

  # genesis prediction handler
  @impl Finitomata
  def on_transition(
        :running_genesis,
        :new_prediction,
        %Prediction{run_index: 0} = new_prediction,
        payload
      ) do
    Networks.broadcast(new_prediction.network_id, {:new_prediction, new_prediction})

    Task.Supervisor.start_child(
      Panic.Runs.TaskSupervisor,
      Panic.Runs.StateMachine,
      :create_prediction_and_transition,
      [new_prediction, payload.tokens],
      restart: :transient
    )

    {:ok, :uninterruptable,
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
      when state in [:uninterruptable, :interruptable] and new_index == head_index + 1 do
    Networks.broadcast(new_prediction.network_id, {:new_prediction, new_prediction})

    Task.Supervisor.start_child(
      Panic.Runs.TaskSupervisor,
      Panic.Runs.StateMachine,
      :create_prediction_and_transition,
      [new_prediction, payload.tokens],
      restart: :transient
    )

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
  def on_transition(_state, :unlock, _prev_state, payload) do
    ## TODO figure out how to re-start the run if prev_state == :running
    reset_payload(payload)
  end

  @impl Finitomata
  def on_transition(_state, :reset, _event_payload, payload) do
    reset_payload(payload)
  end

  @impl Finitomata
  def on_enter(state, %Finitomata.State{payload: %{network: network}}) do
    Networks.broadcast(network.id, {:state_change, state})
    :ok
  end

  ####################
  # helper functions #
  ####################

  def create_prediction_and_transition(input, %Network{} = network, tokens)
      when is_binary(input) do
    Networks.broadcast(network.id, {:prediction_incoming, 0})

    with {:ok, prediction} <- Predictions.create_genesis_prediction(input, network, tokens) do
      Finitomata.transition(prediction.network_id, {:new_prediction, prediction})
    end
  end

  def create_prediction_and_transition(%Prediction{} = previous_prediction, tokens) do
    Networks.broadcast(
      previous_prediction.network_id,
      {:prediction_incoming, previous_prediction.run_index + 1}
    )

    with {:ok, prediction} <- Predictions.create_next_prediction(previous_prediction, tokens) do
      Finitomata.transition(prediction.network_id, {:new_prediction, prediction})
    end
  end

  defp next_state(_state, payload) do
    if seconds_since_prediction(payload.genesis_prediction) > 30 do
      :interruptable
    else
      :uninterruptable
    end
  end

  defp seconds_since_prediction(%Prediction{inserted_at: inserted_at}),
    do: NaiveDateTime.utc_now() |> NaiveDateTime.diff(inserted_at, :second)

  defp reset_payload(payload) do
    {:ok, :ready,
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

  def get_current_state(network_id) do
    %Finitomata.State{current: state} = Finitomata.state(network_id)
    state
  end

  def get_tokens(network_id) do
    %Finitomata.State{payload: %{tokens: tokens}} = Finitomata.state(network_id)
    tokens
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
