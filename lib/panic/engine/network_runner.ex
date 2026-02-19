defmodule Panic.Engine.NetworkRunner do
  @moduledoc """
  A GenServer that manages the execution of a network's invocation runs.

  The NetworkRunner acts as a state machine with two logical states:
  - **idle**: No current run, ready to accept new runs
  - **running**: Actively processing a run with a genesis invocation

  ## Key Features
  - **Crash-resilient**: User context is loaded dynamically from the network relationship, allowing the process to survive restarts without losing authorization context
  - Manages invocation lifecycle from creation to completion
  - Enforces network lockout periods between runs
  - Implements gradual backoff delays between invocations based on run age:
    - Genesis < 10 minutes old: 1 second delay before next invocation
    - Genesis 10 minutes - 1 hour old: 15 second delay before next invocation
    - Genesis > 1 hour old: 10 minute delay before next invocation
  - Handles async invocation processing without blocking the GenServer
  - Dispatches to watchers (like Vestaboard) asynchronously
  - Archives multimedia outputs asynchronously

  ## State Management
  The state contains:
  - `network_id`: The ID of the network being processed (used to dynamically load user context)
  - `genesis_invocation`: The first invocation of the current run (nil when idle)
  - `current_invocation`: The invocation currently being processed (nil when idle)
  - `watchers`: List of active watchers for this network
  - `next_invocation`: The next invocation waiting to be processed (nil when no pending invocation)
  - `next_invocation_time`: Absolute DateTime when the next invocation should be processed (nil when no delay)

  **Note**: User context is no longer stored in state but loaded dynamically from the network relationship using system actor privileges. This makes the NetworkRunner crash-resilient while maintaining proper authorization.

  ## Configuration
  NetworkRunner processes are dynamically started and registered by network ID.
  Each network can have at most one NetworkRunner process at a time.

  ## Testing Considerations
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

  # for async operations to prevent blocking GenServer
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

  ## Authorization and Token Resolution
  The NetworkRunner always acts on behalf of the network owner. All Ash operations
  use the network owner as the actor, and all API tokens (for models and Vestaboards)
  are resolved from the network owner's credentials. This provides a consistent
  execution model regardless of who initiates the run (authenticated users or
  anonymous users via QR codes).

  ## Returns
  - `{:ok, invocation}` - Successfully started, returns the genesis invocation
  - `{:lockout, invocation}` - Rejected due to lockout, returns the current genesis invocation

  ## Examples
      # Start a new run
      iex> NetworkRunner.start_run(1, "Hello world")
      {:ok, %Invocation{...}}

      # Too soon after previous run
      iex> NetworkRunner.start_run(1, "Another prompt")
      {:lockout, %Invocation{...}}
  """
  def start_run(network_id, prompt) do
    case Registry.lookup(NetworkRegistry, network_id) do
      [{pid, _}] ->
        GenServer.call(pid, {:start_run, prompt})

      [] ->
        # Start the NetworkRunner if it doesn't exist
        case DynamicSupervisor.start_child(
               Panic.Engine.NetworkSupervisor,
               {__MODULE__, network_id: network_id}
             ) do
          {:ok, pid} ->
            GenServer.call(pid, {:start_run, prompt})

          {:error, {:already_started, pid}} ->
            GenServer.call(pid, {:start_run, prompt})

          error ->
            error
        end
    end
  end

  @doc """
  Gets the current state of the NetworkRunner.

  ## Parameters
  - `network_id` - The ID of the network

  ## Returns
  - `{:ok, state_map}` - Map with current runner state information
  - `{:error, :not_running}` - NetworkRunner not active

  ## Examples
      iex> NetworkRunner.get_runner_state(1)
      {:ok, %{status: :waiting, ...}}
  """
  def get_runner_state(network_id) do
    case Registry.lookup(NetworkRegistry, network_id) do
      [{pid, _}] -> GenServer.call(pid, :get_runner_state)
      [] -> {:error, :not_running}
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
      next_invocation: nil,
      next_invocation_time: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:start_run, prompt}, _from, state) do
    case state do
      %{genesis_invocation: nil} ->
        # Idle state - start new run
        handle_start_run_idle(prompt, state)

      %{genesis_invocation: genesis} ->
        # Running state - check lockout
        handle_start_run_running(prompt, genesis, state)
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:get_runner_state, _from, state) do
    response = %{
      genesis_invocation: state.genesis_invocation,
      current_invocation: state.current_invocation,
      next_invocation_time: state.next_invocation_time
    }

    {:reply, {:ok, response}, state}
  end

  @impl true
  def handle_call(:stop_run, _from, state) do
    case state do
      %{genesis_invocation: nil} ->
        # Already idle
        {:reply, {:ok, :not_running}, state}

      %{current_invocation: _current} ->
        new_state = %{
          state
          | genesis_invocation: nil,
            current_invocation: nil,
            next_invocation: nil,
            next_invocation_time: nil
        }

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
  def handle_info({:delayed_invocation, invocation}, state) do
    # Process the delayed invocation
    new_state = %{
      state
      | current_invocation: invocation,
        next_invocation: nil,
        next_invocation_time: nil
    }

    trigger_invocation(invocation, new_state)
    {:noreply, new_state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private functions

  defp handle_start_run_idle(prompt, state) do
    {network, network_owner} = get_network_and_user!(state.network_id)
    watchers = vestaboard_watchers(network)

    opts = [actor: network_owner]

    case Engine.prepare_first(network, prompt, opts) do
      {:ok, invocation} ->
        # Make the genesis visible immediately via about_to_invoke
        invocation = Engine.about_to_invoke!(invocation, opts)

        # Dispatch watchers for the genesis invocation immediately (synchronous)
        maybe_dispatch_watchers(invocation, watchers, network_owner)

        new_state = %{
          state
          | genesis_invocation: invocation,
            current_invocation: invocation,
            watchers: watchers,
            next_invocation: nil
        }

        # initial_prompt watchers need delay between display and processing
        # If there are initial_prompt vestaboard watchers, they display the genesis input
        # immediately above, but we delay the actual invocation processing
        # to give users time to read the prompt before it gets processed and replaced
        # with the output. For genesis, we use 2x the normal vestaboard delay.
        if has_initial_prompt_watchers?(watchers) do
          # For genesis invocation with vestaboard watchers, add another 2s delay
          genesis_delay_ms = @vestaboard_delay + 2000
          Process.send_after(self(), {:delayed_invocation, invocation}, genesis_delay_ms)
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

  defp handle_start_run_running(prompt, genesis, state) do
    {network, network_owner} = get_network_and_user!(state.network_id)

    if under_lockout?(genesis, network) do
      {:reply, {:lockout, genesis}, state}
    else
      # Cancel current run and start new one
      if state.current_invocation && state.current_invocation.state == :invoking do
        Engine.mark_as_failed!(state.current_invocation, actor: network_owner)
      end

      watchers = vestaboard_watchers(network)

      opts = [actor: network_owner]

      case Engine.prepare_first(network, prompt, opts) do
        {:ok, invocation} ->
          # Make the genesis visible immediately via about_to_invoke
          invocation = Engine.about_to_invoke!(invocation, opts)

          # Dispatch watchers for the genesis invocation immediately (synchronous)
          maybe_dispatch_watchers(invocation, watchers, network_owner)

          new_state = %{
            state
            | genesis_invocation: invocation,
              current_invocation: invocation,
              watchers: watchers,
              next_invocation: nil
          }

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

  defp handle_processing_completed_normal(%{state: :failed} = _invocation, state) do
    Logger.info("Invocation failed, returning to idle")

    new_state = %{
      state
      | genesis_invocation: nil,
        current_invocation: nil,
        next_invocation: nil,
        next_invocation_time: nil
    }

    {:noreply, new_state}
  end

  defp handle_processing_completed_normal(invocation, state) do
    {network, network_owner} = get_network_and_user!(state.network_id)

    opts = [actor: network_owner]

    case Engine.prepare_next(invocation, opts) do
      {:ok, next_invocation} ->
        # Archive if needed (async) - handle missing models gracefully
        case Panic.Model.by_id(invocation.model) do
          nil ->
            # Model doesn't exist, skip archiving
            :ok

          model ->
            if model.output_type in [:image, :audio] do
              archive_invocation_async(invocation, next_invocation)
            end
        end

        # Dispatch to Vestaboard watchers and check if any were dispatched
        watchers = vestaboard_watchers(network)
        # Always use network owner for Vestaboard tokens
        vestaboard_dispatched = maybe_dispatch_watchers(invocation, watchers, network_owner)

        # Calculate when the next invocation should happen
        next_invocation_time =
          calculate_next_invocation_time(state.genesis_invocation, vestaboard_dispatched)

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
        new_state = %{
          state
          | genesis_invocation: nil,
            current_invocation: nil,
            next_invocation: nil,
            next_invocation_time: nil
        }

        {:noreply, new_state}
    end
  end

  defp under_lockout?(genesis_invocation, network) do
    lockout_seconds = network.lockout_seconds
    lockout_ms = lockout_seconds * 1000

    case DateTime.compare(
           DateTime.utc_now(),
           DateTime.add(genesis_invocation.inserted_at, lockout_ms, :millisecond)
         ) do
      :lt -> true
      _ -> false
    end
  end

  defp trigger_invocation(invocation, state) do
    {_network, network_owner} = get_network_and_user!(state.network_id)
    opts = [actor: network_owner]
    genserver_pid = self()

    do_invoke = fn ->
      with {:ok, invocation} <- Engine.about_to_invoke(invocation, opts),
           {:ok, processed} <- Engine.invoke(invocation, opts) do
        send(genserver_pid, {:processing_completed, processed})
      else
        {:error, error} ->
          Logger.error("Invocation processing failed: #{inspect(error)}")
          Engine.mark_as_failed(invocation, opts)
          failed = Engine.get_invocation!(invocation.id, opts)
          send(genserver_pid, {:processing_completed, failed})
      end
    end

    if Application.get_env(:panic, :sync_network_runner, false) do
      do_invoke.()
    else
      Task.Supervisor.start_child(@task_supervisor, do_invoke)
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
      %{stride: stride, offset: offset, initial_prompt: initial_prompt} = watcher

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
        # Use vestaboard_name (atom) not name (string) for token lookup
        vestaboard_name = Map.get(watcher, :vestaboard_name)
        board_name = Atom.to_string(vestaboard_name)
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

  defp calculate_next_invocation_time(genesis_invocation, vestaboard_dispatched) do
    now = DateTime.utc_now()
    age_ms = DateTime.diff(now, genesis_invocation.inserted_at, :millisecond)

    # Calculate base delay based on genesis invocation age
    base_delay_ms =
      cond do
        age_ms < to_timeout(minute: 10) -> to_timeout(second: 1)
        age_ms < to_timeout(hour: 1) -> to_timeout(second: 15)
        true -> to_timeout(minute: 10)
      end

    # Add additional delay if vestaboards were dispatched
    vestaboard_delay_ms = if vestaboard_dispatched, do: @vestaboard_delay, else: 0

    # Use the longer of the two delays
    total_delay_ms = max(base_delay_ms, vestaboard_delay_ms)

    # Return the absolute time when the next invocation should happen
    DateTime.add(now, total_delay_ms, :millisecond)
  end
end
