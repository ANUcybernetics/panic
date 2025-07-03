defmodule Panic.Engine.NetworkRunner do
  @moduledoc """
  A GenServer that manages the execution of a network's invocation runs.

  The NetworkRunner acts as a state machine with two logical states:
  - **idle**: No current run, ready to accept new runs
  - **running**: Actively processing a run with a genesis invocation

  ## Key Features
  - **Crash-resilient**: User context is loaded dynamically from the network relationship using system context, allowing the process to survive restarts without losing authorization context
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
  - `network_id`: The ID of the network being processed (used to dynamically load user context)
  - `genesis_invocation`: The first invocation of the current run (nil when idle)
  - `current_invocation`: The invocation currently being processed (nil when idle)
  - `watchers`: List of active watchers for this network
  - `lockout_timer`: Timer reference for broadcasting lockout countdown (nil when not in lockout)
  - `next_invocation`: The next invocation waiting to be processed (nil when no pending invocation)
  - `next_invocation_time`: Absolute DateTime when the next invocation should be processed (nil when no delay)

  **Note**: User context is no longer stored in state but loaded dynamically from the network relationship using system actor privileges. This makes the NetworkRunner crash-resilient while maintaining proper authorization.

  ## Configuration
  NetworkRunner processes are dynamically started and registered by network ID.
  Each network can have at most one NetworkRunner process at a time.

  ## Testing Considerations
  # AIDEV-NOTE: NetworkRunner persists across tests; requires cleanup in test setup
  NetworkRunner GenServers persist in the NetworkRegistry across test runs. While they
  no longer maintain stale user state (user is loaded dynamically), they should still
  be cleaned up between tests. Use PanicWeb.Helpers.stop_all_network_runners/0 in test setup.
  """

  use GenServer

  alias Panic.Engine
  alias Panic.Engine.Archiver
  alias Panic.Engine.NetworkRegistry
  alias Panic.Platforms.Vestaboard

  require Logger

  # AIDEV-NOTE: Task supervisor for async operations to prevent blocking GenServer
  @task_supervisor Panic.Engine.TaskSupervisor

  # add extra latency for vestabords to "catch up"
  @vestaboard_delay 8_000

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
      genesis_invocation: nil,
      current_invocation: nil,
      watchers: [],
      lockout_timer: nil,
      next_invocation: nil,
      next_invocation_time: nil
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

      %{current_invocation: _current} ->
        # Stop current run - let current invocation complete naturally

        new_state =
          stop_lockout_timer(%{
            state
            | genesis_invocation: nil,
              current_invocation: nil,
              next_invocation: nil,
              next_invocation_time: nil
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
        network = Ash.get!(Engine.Network, state.network_id, authorize?: false)
        remaining_seconds = calculate_lockout_remaining(genesis, network)

        if remaining_seconds >= 0 do
          # Only broadcast if there are viewers watching
          viewers = PanicWeb.InvocationWatcher.list_viewers(state.network_id)

          if length(viewers) > 0 do
            PanicWeb.Endpoint.broadcast("invocation:#{state.network_id}", "lockout_countdown", %{
              seconds_remaining: remaining_seconds
            })
          end

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
    new_state = %{state | current_invocation: invocation, next_invocation: nil, next_invocation_time: nil}
    trigger_invocation(invocation, new_state)
    {:noreply, new_state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private functions

  defp handle_start_run_idle(prompt, user, state) do
    network = Ash.get!(Engine.Network, state.network_id, authorize?: false)
    watchers = vestaboard_watchers(network)

    # Set anonymous context if user is nil
    opts = if user, do: [actor: user], else: [actor: nil, context: %{anonymous: true}]

    case Engine.prepare_first(network, prompt, opts) do
      {:ok, invocation} ->
        # Make the genesis visible immediately via about_to_invoke
        invocation = Engine.about_to_invoke!(invocation, opts)

        # Dispatch watchers for the genesis invocation immediately (synchronous)
        maybe_dispatch_watchers(invocation, watchers, user)

        new_state =
          start_lockout_timer(
            %{
              state
              | genesis_invocation: invocation,
                current_invocation: invocation,
                watchers: watchers,
                next_invocation: nil
            },
            invocation,
            network
          )

        # AIDEV-NOTE: initial_prompt watchers need delay between display and processing
        # If there are initial_prompt vestaboard watchers, they display the genesis input
        # immediately above, but we delay the actual invocation processing
        # to give users time to read the prompt before it gets processed and replaced
        # with the output. This matches the vestaboard delay used elsewhere.
        if has_initial_prompt_watchers?(watchers) do
          Process.send_after(self(), {:delayed_invocation, invocation}, @vestaboard_delay)
        else
          # Trigger async invocation processing immediately
          trigger_invocation(invocation, new_state)
        end

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
    network = Ash.get!(Engine.Network, state.network_id, authorize?: false)

    if under_lockout?(genesis, network) do
      {:reply, {:lockout, genesis}, state}
    else
      # Cancel current run and start new one
      if state.current_invocation && state.current_invocation.state == :invoking do
        # Set anonymous context if user is nil
        opts = if user, do: [actor: user], else: [actor: nil, context: %{anonymous: true}]
        Engine.mark_as_failed!(state.current_invocation, opts)
      end

      watchers = vestaboard_watchers(network)

      # Set anonymous context if user is nil
      opts = if user, do: [actor: user], else: [actor: nil, context: %{anonymous: true}]

      case Engine.prepare_first(network, prompt, opts) do
        {:ok, invocation} ->
          # Make the genesis visible immediately via about_to_invoke
          invocation = Engine.about_to_invoke!(invocation, opts)

          # Dispatch watchers for the genesis invocation immediately (synchronous)
          maybe_dispatch_watchers(invocation, watchers, user)

          new_state =
            %{
              state
              | genesis_invocation: invocation,
                current_invocation: invocation,
                watchers: watchers,
                next_invocation: nil
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
    {network, user} = get_network_and_user!(state.network_id)

    # Set anonymous context if user is nil
    opts = if user, do: [actor: user], else: [actor: nil, context: %{anonymous: true}]

    case Engine.prepare_next(invocation, opts) do
      {:ok, next_invocation} ->
        # Archive if needed (async)
        model = Panic.Model.by_id!(invocation.model)

        if model.output_type in [:image, :audio] do
          archive_invocation_async(invocation, next_invocation)
        end

        # Dispatch to Vestaboard watchers and check if any were dispatched
        watchers = vestaboard_watchers(network)
        vestaboard_dispatched = maybe_dispatch_watchers(invocation, watchers, user)

        # Calculate when the next invocation should happen
        next_invocation_time = calculate_next_invocation_time(state.genesis_invocation, vestaboard_dispatched)

        # Calculate delay from now until next invocation time
        now = DateTime.utc_now()
        delay_ms = max(0, DateTime.diff(next_invocation_time, now, :millisecond))

        # Schedule delayed invocation
        Process.send_after(self(), {:delayed_invocation, next_invocation}, delay_ms)

        new_state = %{
          state
          | current_invocation: nil,
            next_invocation: next_invocation,
            next_invocation_time: next_invocation_time
        }

        {:noreply, new_state}

      {:error, error} ->
        Logger.error("Failed to prepare next invocation: #{inspect(error)}")
        # Return to idle on error
        new_state = %{
          state
          | genesis_invocation: nil,
            current_invocation: nil,
            next_invocation: nil,
            next_invocation_time: nil
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
            next_invocation: nil,
            next_invocation_time: nil
        })

      {:noreply, new_state}
  end

  defp under_lockout?(genesis_invocation, network) do
    lockout_seconds = network.lockout_seconds
    lockout_ms = lockout_seconds * 1000

    case DateTime.compare(DateTime.utc_now(), DateTime.add(genesis_invocation.inserted_at, lockout_ms, :millisecond)) do
      :lt -> true
      _ -> false
    end
  end

  defp trigger_invocation(invocation, state) do
    # Get user dynamically - NetworkRunner is now crash-resilient
    {_network, user} = get_network_and_user!(state.network_id)

    # Set anonymous context if user is nil
    opts = if user, do: [actor: user], else: [actor: nil, context: %{anonymous: true}]

    if Application.get_env(:panic, :sync_network_runner, false) do
      # Synchronous mode for tests - send message to self but process immediately
      try do
        # Make the invocation visible with pending state first
        invocation = Engine.about_to_invoke!(invocation, opts)
        processed_invocation = Engine.invoke!(invocation, opts)
        send(self(), {:processing_completed, processed_invocation})
      rescue
        e ->
          # Mark invocation as failed before logging error
          try do
            Engine.mark_as_failed!(invocation, opts)
          rescue
            # If marking as failed fails, just continue
            _mark_error -> nil
          end

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
            invocation = Engine.about_to_invoke!(invocation, opts)
            # Process the invocation
            processed_invocation = Engine.invoke!(invocation, opts)

            # Notify completion to the GenServer
            send(genserver_pid, {:processing_completed, processed_invocation})
          rescue
            e ->
              # Mark invocation as failed before logging error
              try do
                Engine.mark_as_failed!(invocation, opts)
              rescue
                # If marking as failed fails, just continue
                _mark_error -> nil
              end

              Logger.error("Invocation processing failed: #{inspect(e)}")
              # Don't crash - just let the run end
          end
        end)
    end
  end

  @doc """
  Archives an invocation asynchronously using Task.Supervisor.

  This function spawns a supervised task to archive the given invocation
  along with context from the next invocation. Archiving is done as a
  best-effort operation and will not crash the NetworkRunner if it fails.

  ## Parameters

  - `invocation` - The invocation to archive
  - `next_invocation` - The next invocation for context

  ## Returns

  - `{:ok, task_pid}` - The PID of the spawned archiving task

  ## Examples

      iex> NetworkRunner.archive_invocation_async(invocation, next_invocation)
      {:ok, #PID<0.234.0>}

  """
  def archive_invocation_async(invocation, next_invocation) do
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

  # AIDEV-NOTE: Helper to get network and user context - makes NetworkRunner crash-resilient
  defp has_initial_prompt_watchers?(watchers) when is_list(watchers) do
    Enum.any?(watchers, fn watcher ->
      Map.get(watcher, :initial_prompt, false)
    end)
  end

  defp get_network_and_user!(network_id) do
    # Use authorize?: false to read network and user since NetworkRunner is a system service
    # This allows the process to survive restarts and still access the required user context
    # Only call this when user context is actually needed to minimize database calls
    network =
      Ash.get!(Engine.Network, network_id,
        authorize?: false,
        load: [:user]
      )

    {network, network.user}
  end

  defp vestaboard_watchers(network) do
    # Ensure installations are loaded (skip auth checks – we already authorized the network)
    network = Ash.load!(network, :installations, authorize?: false)

    Enum.flat_map(network.installations || [], fn installation ->
      Enum.filter(installation.watchers, &(&1.type == :vestaboard))
    end)
  end

  defp maybe_dispatch_watchers(%{sequence_number: seq} = inv, watchers, user) when is_list(watchers) do
    Enum.any?(watchers, fn watcher ->
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
            true

          {:error, _reason} ->
            # error message has already been logged, so no need to re-log it
            true
        end
      else
        false
      end
    end)
  end

  defp maybe_dispatch_watchers(_inv, _watchers, _user), do: false

  # AIDEV-NOTE: Lockout timer management for broadcasting countdown to clients
  defp start_lockout_timer(state, genesis_invocation, network) do
    # Stop any existing timer first
    state = stop_lockout_timer(state)

    remaining_seconds = calculate_lockout_remaining(genesis_invocation, network)

    if remaining_seconds > 0 do
      # Only broadcast if there are viewers watching
      viewers = PanicWeb.InvocationWatcher.list_viewers(state.network_id)

      if length(viewers) > 0 do
        PanicWeb.Endpoint.broadcast("invocation:#{state.network_id}", "lockout_countdown", %{
          seconds_remaining: remaining_seconds
        })
      end

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
    lockout_seconds = network.lockout_seconds
    lockout_end = DateTime.add(genesis_invocation.inserted_at, lockout_seconds, :second)

    case DateTime.compare(DateTime.utc_now(), lockout_end) do
      :lt -> DateTime.diff(lockout_end, DateTime.utc_now(), :second)
      _ -> 0
    end
  end

  # AIDEV-NOTE: Calculates absolute time for next invocation based on genesis age & vestaboard dispatch
  # This replaces the old calculate_invocation_delay/calculate_combined_delay approach for cleaner timing
  defp calculate_next_invocation_time(genesis_invocation, vestaboard_dispatched) do
    now = DateTime.utc_now()
    age_seconds = DateTime.diff(now, genesis_invocation.inserted_at, :second)

    # Calculate base delay based on genesis invocation age
    base_delay_ms =
      cond do
        age_seconds < to_timeout(minute: 10) -> to_timeout(second: 1)
        age_seconds < to_timeout(hour: 1) -> to_timeout(second: 15)
        true -> to_timeout(hour: 1)
      end

    # Add additional delay if vestaboards were dispatched
    vestaboard_delay_ms = if vestaboard_dispatched, do: @vestaboard_delay, else: 0

    # Use the longer of the two delays
    total_delay_ms = max(base_delay_ms, vestaboard_delay_ms)

    # Return the absolute time when the next invocation should happen
    DateTime.add(now, total_delay_ms, :millisecond)
  end
end
