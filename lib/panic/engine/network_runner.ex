defmodule Panic.Engine.NetworkRunner do
  @moduledoc """
  A GenServer that manages the execution of a network's invocation runs.

  The NetworkRunner acts as a state machine with two logical states:
  - **idle**: No current run, ready to accept new runs
  - **running**: Actively processing a run with a genesis invocation

  ## Key Features
  - Manages invocation lifecycle from creation to completion
  - Enforces network lockout periods between runs
  - Implements gradual backoff delays between invocations based on run age:
    - Genesis < 5 minutes old: Process next invocation immediately
    - Genesis 5 minutes - 1 hour old: 30 second delay before next invocation
    - Genesis > 1 hour old: 1 hour delay before next invocation
  - Handles async invocation processing without blocking the GenServer
  - Dispatches to watchers (like Vestaboard) asynchronously
  - Archives multimedia outputs asynchronously

  ## State Management
  The state contains:
  - `network_id`: The ID of the network being processed
  - `user`: The user who started the current run
  - `genesis_invocation`: The first invocation of the current run (nil when idle)
  - `current_invocation`: The invocation currently being processed (nil when idle)
  - `watchers`: List of active watchers for this network
  - `lockout_timer`: Timer reference for broadcasting lockout countdown (nil when not in lockout)
  - `pending_delayed_invocation`: Invocation waiting for scheduled delay before processing (nil when no delay)

  ## Configuration
  NetworkRunner processes are dynamically started and registered by network ID.
  Each network can have at most one NetworkRunner process at a time.

  ## Testing Considerations
  # AIDEV-NOTE: NetworkRunner persists across tests; requires cleanup in test setup
  NetworkRunner GenServers persist in the NetworkRegistry across test runs and maintain
  user state. This can cause Ash.Error.Forbidden when stale processes run with wrong
  actor context. Use PanicWeb.Helpers.stop_all_network_runners/0 in test setup.
  """

  use GenServer

  alias Panic.Engine
  alias Panic.Engine.Archiver
  alias Panic.Engine.NetworkRegistry
  alias Panic.Platforms.Vestaboard

  require Logger

  # AIDEV-NOTE: Task supervisor for async operations to prevent blocking GenServer
  @task_supervisor Panic.Engine.TaskSupervisor

  @doc """
  Starts a NetworkRunner GenServer for the given network.

  This function is typically called by the DynamicSupervisor when a new
  NetworkRunner is needed for a network.

  ## Options
  - `network_id` - The ID of the network this runner will manage

  ## Examples
      iex> NetworkRunner.start_link(network_id: 1)
      {:ok, #PID<0.123.0>}
  """
  def start_link(opts) do
    network_id = Keyword.fetch!(opts, :network_id)
    GenServer.start_link(__MODULE__, network_id, name: {:via, Registry, {NetworkRegistry, network_id}})
  end

  @doc """
  Starts a new invocation run for the given network.

  If no NetworkRunner exists for the network, it will be started automatically.
  If a run is already in progress, lockout rules apply based on the network's settings.

  ## Parameters
  - `network_id` - The ID of the network to run
  - `prompt` - The initial prompt text
  - `user` - The user starting the run

  ## Returns
  - `{:ok, invocation}` - Successfully started, returns the genesis invocation
  - `{:lockout, invocation}` - Rejected due to lockout, returns the current genesis invocation

  ## Examples
      # Start a new run
      iex> NetworkRunner.start_run(1, "Hello world", user)
      {:ok, %Invocation{...}}

      # Too soon after previous run
      iex> NetworkRunner.start_run(1, "Another prompt", user)
      {:lockout, %Invocation{...}}
  """
  def start_run(network_id, prompt, user) do
    case Registry.lookup(NetworkRegistry, network_id) do
      [{pid, _}] ->
        GenServer.call(pid, {:start_run, prompt, user})

      [] ->
        # Start the NetworkRunner if it doesn't exist
        case DynamicSupervisor.start_child(
               Panic.Engine.NetworkSupervisor,
               {__MODULE__, network_id: network_id}
             ) do
          {:ok, pid} ->
            GenServer.call(pid, {:start_run, prompt, user})

          {:error, {:already_started, pid}} ->
            GenServer.call(pid, {:start_run, prompt, user})

          error ->
            error
        end
    end
  end

  @doc """
  Stops the current run for the given network.

  ## Parameters
  - `network_id` - The ID of the network to stop

  ## Returns
  - `{:ok, :stopped}` - Successfully stopped the run
  - `{:ok, :not_running}` - No run was active

  ## Examples
      iex> NetworkRunner.stop_run(1)
      {:ok, :stopped}
  """
  def stop_run(network_id) do
    case Registry.lookup(NetworkRegistry, network_id) do
      [{pid, _}] -> GenServer.call(pid, :stop_run)
      [] -> {:ok, :not_running}
    end
  end

  @impl true
  def init(network_id) do
    state = %{
      network_id: network_id,
      user: nil,
      genesis_invocation: nil,
      current_invocation: nil,
      watchers: [],
      lockout_timer: nil,
      pending_delayed_invocation: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:start_run, prompt, user}, _from, state) do
    case state do
      %{genesis_invocation: nil} ->
        # Idle state - start new run
        handle_start_run_idle(prompt, user, state)

      %{genesis_invocation: genesis} ->
        # Running state - check lockout
        handle_start_run_running(prompt, user, genesis, state)
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:stop_run, _from, state) do
    case state do
      %{genesis_invocation: nil} ->
        # Already idle
        {:reply, {:ok, :not_running}, state}

      %{current_invocation: current} ->
        # Stop current run
        try do
          if current && current.state == :invoking do
            Engine.cancel!(current, actor: state.user)
          end
        rescue
          e -> Logger.error("Error canceling invocation during stop: #{inspect(e)}")
        end

        new_state =
          stop_lockout_timer(%{
            state
            | genesis_invocation: nil,
              current_invocation: nil,
              user: nil,
              pending_delayed_invocation: nil
          })

        {:reply, {:ok, :stopped}, new_state}
    end
  end

  @impl true
  def handle_info({:processing_completed, invocation}, state) do
    case state do
      %{genesis_invocation: nil} ->
        # Idle state - ignore stale completion
        Logger.debug("Ignoring stale processing completion in idle state")
        {:noreply, state}

      %{current_invocation: current} when current.id == invocation.id ->
        # Valid completion for current invocation
        handle_processing_completed(invocation, state)

      _ ->
        # Stale completion - ignore
        Logger.debug("Ignoring stale processing completion for invocation #{invocation.id}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:lockout_tick, state) do
    case state do
      %{genesis_invocation: %{} = genesis} ->
        network = Ash.get!(Engine.Network, state.network_id, actor: state.user)
        remaining_seconds = calculate_lockout_remaining(genesis, network)

        if remaining_seconds >= 0 do
          # Broadcast the countdown
          PanicWeb.Endpoint.broadcast("invocation:#{state.network_id}", "lockout_countdown", %{
            seconds_remaining: remaining_seconds
          })

          if remaining_seconds > 0 do
            # Schedule next tick
            timer_ref = Process.send_after(self(), :lockout_tick, 1000)
            {:noreply, %{state | lockout_timer: timer_ref}}
          else
            # Lockout expired after broadcasting final 0, stop timer
            new_state = stop_lockout_timer(state)
            {:noreply, new_state}
          end
        else
          # Lockout expired, stop broadcasting
          new_state = stop_lockout_timer(state)
          {:noreply, new_state}
        end

      _ ->
        # No genesis invocation, stop timer
        new_state = stop_lockout_timer(state)
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:delayed_invocation, invocation}, state) do
    # Process the delayed invocation
    new_state = %{state | current_invocation: invocation, pending_delayed_invocation: nil}
    trigger_invocation(invocation, new_state)
    {:noreply, new_state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private functions

  defp handle_start_run_idle(prompt, user, state) do
    network = Ash.get!(Engine.Network, state.network_id, actor: user)
    watchers = vestaboard_watchers(network)

    case Engine.prepare_first(network, prompt, actor: user) do
      {:ok, invocation} ->
        # Make the genesis visible immediately via about_to_invoke
        invocation = Engine.about_to_invoke!(invocation, actor: user)

        # Dispatch watchers for the genesis invocation immediately (synchronous)
        maybe_dispatch_watchers(invocation, watchers, user)

        new_state =
          start_lockout_timer(
            %{
              state
              | user: user,
                genesis_invocation: invocation,
                current_invocation: invocation,
                watchers: watchers,
                pending_delayed_invocation: nil
            },
            invocation,
            network
          )

        # Trigger async invocation processing
        trigger_invocation(invocation, new_state)

        {:reply, {:ok, invocation}, new_state}

      {:error, error} ->
        Logger.error("Failed to prepare first invocation: #{inspect(error)}")
        {:reply, {:error, error}, state}
    end
  rescue
    e ->
      Logger.error("Error starting run in idle state: #{inspect(e)}")
      {:reply, {:error, e}, state}
  end

  defp handle_start_run_running(prompt, user, genesis, state) do
    network = Ash.get!(Engine.Network, state.network_id, actor: user)

    if under_lockout?(genesis, network) do
      {:reply, {:lockout, genesis}, state}
    else
      # Cancel current run and start new one
      if state.current_invocation && state.current_invocation.state == :invoking do
        Engine.cancel!(state.current_invocation, actor: user)
      end

      watchers = vestaboard_watchers(network)

      case Engine.prepare_first(network, prompt, actor: user) do
        {:ok, invocation} ->
          # Make the genesis visible immediately via about_to_invoke
          invocation = Engine.about_to_invoke!(invocation, actor: user)

          # Dispatch watchers for the genesis invocation immediately (synchronous)
          maybe_dispatch_watchers(invocation, watchers, user)

          new_state =
            %{
              state
              | user: user,
                genesis_invocation: invocation,
                current_invocation: invocation,
                watchers: watchers,
                pending_delayed_invocation: nil
            }
            |> stop_lockout_timer()
            |> start_lockout_timer(invocation, network)

          # Trigger async invocation processing
          trigger_invocation(invocation, new_state)

          {:reply, {:ok, invocation}, new_state}

        {:error, error} ->
          Logger.error("Failed to prepare first invocation: #{inspect(error)}")
          {:reply, {:error, error}, state}
      end
    end
  rescue
    e ->
      Logger.error("Error starting run in running state: #{inspect(e)}")
      {:reply, {:error, e}, state}
  end

  defp handle_processing_completed(invocation, state) do
    # Dispatch watchers for completed invocation output
    maybe_dispatch_watchers(invocation, state.watchers, state.user)

    # In sync test mode, prevent infinite loops but preserve lockout behavior
    if Application.get_env(:panic, :sync_network_runner, false) do
      # For tests, stop creating new invocations after the first one completes
      # but keep the genesis_invocation for lockout functionality
      Logger.info("Test mode: preventing infinite loop after invocation #{invocation.sequence_number}")
      new_state = %{state | current_invocation: nil}
      {:noreply, new_state}
    else
      handle_processing_completed_normal(invocation, state)
    end
  end

  defp handle_processing_completed_normal(invocation, state) do
    case Engine.prepare_next(invocation, actor: state.user) do
      {:ok, next_invocation} ->
        # Archive if needed (async)
        model = Panic.Model.by_id!(invocation.model)

        if model.output_type in [:image, :audio] do
          archive_invocation_async(invocation, next_invocation)
        end

        # Calculate delay based on genesis invocation age
        delay_ms = calculate_invocation_delay(state.genesis_invocation)

        if delay_ms > 0 do
          # Schedule delayed invocation
          Process.send_after(self(), {:delayed_invocation, next_invocation}, delay_ms)
          new_state = %{state | current_invocation: nil, pending_delayed_invocation: next_invocation}
          {:noreply, new_state}
        else
          # Continue with next invocation immediately
          new_state = %{state | current_invocation: next_invocation}
          trigger_invocation(next_invocation, new_state)
          {:noreply, new_state}
        end

      {:error, error} ->
        Logger.error("Failed to prepare next invocation: #{inspect(error)}")
        # Return to idle on error
        new_state = %{
          state
          | genesis_invocation: nil,
            current_invocation: nil,
            user: nil,
            pending_delayed_invocation: nil
        }

        {:noreply, new_state}
    end
  rescue
    e ->
      Logger.error("Error handling processing completion: #{inspect(e)}")
      # Return to idle on error
      new_state =
        stop_lockout_timer(%{
          state
          | genesis_invocation: nil,
            current_invocation: nil,
            user: nil,
            pending_delayed_invocation: nil
        })

      {:noreply, new_state}
  end

  defp under_lockout?(genesis_invocation, network) do
    lockout_seconds = network.lockout_seconds || 60
    lockout_ms = lockout_seconds * 1000

    case DateTime.compare(DateTime.utc_now(), DateTime.add(genesis_invocation.inserted_at, lockout_ms, :millisecond)) do
      :lt -> true
      _ -> false
    end
  end

  defp trigger_invocation(invocation, state) do
    if Application.get_env(:panic, :sync_network_runner, false) do
      # Synchronous mode for tests - send message to self but process immediately
      try do
        # Make the invocation visible with pending state first
        invocation = Engine.about_to_invoke!(invocation, actor: state.user)
        processed_invocation = Engine.invoke!(invocation, actor: state.user)
        send(self(), {:processing_completed, processed_invocation})
      rescue
        e ->
          Logger.error("Invocation processing failed: #{inspect(e)}")
          # Don't crash - just let the run end
      end
    else
      # Capture the GenServer pid to send messages back to it
      genserver_pid = self()

      # Process the invocation asynchronously
      {:ok, _task_pid} =
        Task.Supervisor.start_child(@task_supervisor, fn ->
          try do
            # Make the invocation visible with pending state first
            invocation = Engine.about_to_invoke!(invocation, actor: state.user)
            # Process the invocation
            processed_invocation = Engine.invoke!(invocation, actor: state.user)

            # Notify completion to the GenServer
            send(genserver_pid, {:processing_completed, processed_invocation})
          rescue
            e ->
              Logger.error("Invocation processing failed: #{inspect(e)}")
              # Don't crash - just let the run end
          end
        end)
    end
  end

  defp archive_invocation_async(invocation, next_invocation) do
    # Skip archiving in test environment to avoid network requests
    if Mix.env() == :test do
      :ok
    else
      {:ok, _task_pid} =
        Task.Supervisor.start_child(@task_supervisor, fn ->
          try do
            Archiver.archive_invocation(invocation, next_invocation)
          rescue
            e ->
              Logger.error("Archiving failed: #{inspect(e)}")
              # Don't crash - archiving is best effort
          end
        end)
    end
  end

  defp vestaboard_watchers(network) do
    # Ensure installations are loaded (skip auth checks – we already authorized the network)
    network = Ash.load!(network, :installations, authorize?: false)

    Enum.flat_map(network.installations || [], fn installation ->
      Enum.filter(installation.watchers, &(&1.type == :vestaboard))
    end)
  end

  defp maybe_dispatch_watchers(%{sequence_number: seq} = inv, watchers, user) when is_list(watchers) do
    Enum.each(watchers, fn watcher ->
      %{stride: stride, offset: offset, name: name, initial_prompt: initial_prompt} = watcher

      should_dispatch =
        cond do
          # Genesis invocation (seq 0): display input if initial_prompt is true OR offset matches
          seq == 0 and is_binary(inv.input) ->
            initial_prompt or rem(seq, stride) == offset

          # Non-genesis invocations: display output when sequence matches offset
          seq > 0 and is_binary(inv.output) ->
            rem(seq, stride) == offset

          # No match
          true ->
            false
        end

      if should_dispatch do
        board_name = Atom.to_string(name)
        token = Vestaboard.token_for_board!(board_name, user)

        # For genesis (seq 0), display input; otherwise display output
        content = if seq == 0, do: inv.input, else: inv.output

        case Vestaboard.send_text(content, token, board_name) do
          {:ok, _id} ->
            :ok

          {:error, _reason} ->
            # error message has already been logged, so no need to re-log it
            :ok
        end
      end
    end)
  end

  defp maybe_dispatch_watchers(_inv, _watchers, _user), do: :ok

  # AIDEV-NOTE: Lockout timer management for broadcasting countdown to clients
  defp start_lockout_timer(state, genesis_invocation, network) do
    # Stop any existing timer first
    state = stop_lockout_timer(state)

    remaining_seconds = calculate_lockout_remaining(genesis_invocation, network)

    if remaining_seconds > 0 do
      # Start broadcasting countdown immediately, then every second
      PanicWeb.Endpoint.broadcast("invocation:#{state.network_id}", "lockout_countdown", %{
        seconds_remaining: remaining_seconds
      })

      timer_ref = Process.send_after(self(), :lockout_tick, 1000)
      %{state | lockout_timer: timer_ref}
    else
      state
    end
  end

  defp stop_lockout_timer(%{lockout_timer: nil} = state), do: state

  defp stop_lockout_timer(%{lockout_timer: timer_ref} = state) do
    Process.cancel_timer(timer_ref)
    %{state | lockout_timer: nil}
  end

  defp calculate_lockout_remaining(genesis_invocation, network) do
    lockout_seconds = network.lockout_seconds || 60
    lockout_end = DateTime.add(genesis_invocation.inserted_at, lockout_seconds, :second)

    case DateTime.compare(DateTime.utc_now(), lockout_end) do
      :lt -> DateTime.diff(lockout_end, DateTime.utc_now(), :second)
      _ -> 0
    end
  end

  # AIDEV-NOTE: Calculates delay between invocations based on genesis invocation age
  defp calculate_invocation_delay(genesis_invocation) do
    now = DateTime.utc_now()
    age_seconds = DateTime.diff(now, genesis_invocation.inserted_at, :second)

    cond do
      # Less than 5 minutes old - no delay
      age_seconds < 300 -> 0
      # Less than 1 hour old - 30 second delay
      age_seconds < 3600 -> to_timeout(second: 30)
      # More than 1 hour old - 1 hour delay
      true -> to_timeout(hour: 1)
    end
  end
end
