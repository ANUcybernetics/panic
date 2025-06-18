defmodule Panic.Engine.NetworkRunner do
  @moduledoc """
  A GenServer that processes invocations for a specific network.

  Handles recursive invocation processing, lockout periods, and archiving.

  This GenServer replaces the previous Oban-based invocation processing system.
  Each network gets its own NetworkRunner GenServer that is started on demand
  and registered via the NetworkRegistry.

  ## Key Features

  - **Recursive Processing**: Automatically processes invocations in sequence until stopped
  - **Lockout Period**: Enforces a 30-second lockout between genesis invocations
  - **Automatic Archiving**: Archives image/audio outputs to S3-compatible storage
  - **Graceful Cancellation**: Supports stopping runs in progress
  - **Restart on Failure**: Failed invocations trigger a restart of the entire run with the original prompt

  ## State Management

  The GenServer maintains the following state:
  - `network_id`: The ID of the network being processed
  - `current_invocation`: The invocation currently being processed
  - `genesis_invocation`: The first invocation of the current run
  - `user`: The user who started the current run
  - `processing_ref`: Timer reference for the next processing cycle
  - `watchers`: List of active watchers for this network

  ## Configuration

  The lockout period between genesis invocations is configured per-network via the `lockout_seconds` attribute on the Network resource (default: 30).

  ## Testing Considerations

  # AIDEV-NOTE: NetworkRunner persists across tests; requires cleanup in test setup
  NetworkRunner GenServers persist in the NetworkRegistry across test runs and maintain
  user state. This can cause Ash.Error.Forbidden when stale processes run with wrong
  actor context. Use PanicWeb.Helpers.stop_all_network_runners/0 in test setup.

  ## Stop Button Fix

  # AIDEV-NOTE: Fixed timeout crash when stopping active NetworkRunner
  The stop_run operation previously could timeout when Engine.cancel! took too long,
  causing the LiveView to crash. Now Engine.cancel! runs asynchronously to prevent
  blocking the GenServer call response.
  """

  use GenServer

  alias Panic.Engine
  alias Panic.Engine.NetworkRegistry
  alias Panic.Platforms.Vestaboard

  require Logger

  # Client API

  @doc """
  Starts a NetworkRunner for the given network.

  The runner is registered in the NetworkRegistry under the network_id.

  ## Options

    * `:network_id` - Required. The ID of the network to process

  ## Examples

      iex> NetworkRunner.start_link(network_id: 123)
      {:ok, #PID<0.123.0>}
  """
  def start_link(opts) do
    network_id = Keyword.fetch!(opts, :network_id)
    name = {:via, Registry, {NetworkRegistry, network_id}}
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Starts a new run for the network with the given prompt.

  This function will:
  1. Start a NetworkRunner if one isn't already running
  2. Cancel any existing run for the network
  3. Create a new genesis invocation with the given prompt
  4. Begin processing invocations recursively

  ## Parameters

    * `network_id` - The ID of the network to run
    * `prompt` - The initial prompt text
    * `user` - The user starting the run

  ## Returns

    * `{:ok, genesis_invocation}` - Successfully started a new run
    * `{:lockout, genesis_invocation}` - Cannot start due to lockout period (30s)
    * `{:error, reason}` - Failed to start the run

  ## Examples

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
        # Start the runner if it doesn't exist
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
  Stops the current run for the network.

  Cancels any invocation currently being processed and stops the recursive
  processing loop. The NetworkRunner GenServer remains alive and can
  accept new runs.

  ## Parameters

    * `network_id` - The ID of the network to stop

  ## Returns

    * `{:ok, :stopped}` - Successfully stopped the run
    * `{:ok, :not_running}` - No runner was running for this network

  ## Examples

      iex> NetworkRunner.stop_run(1)
      {:ok, :stopped}
  """
  def stop_run(network_id) do
    case Registry.lookup(NetworkRegistry, network_id) do
      [{pid, _}] ->
        GenServer.call(pid, :stop_run)

      [] ->
        {:ok, :not_running}
    end
  end

  # Server callbacks

  @impl true
  def init(opts) do
    network_id = Keyword.fetch!(opts, :network_id)

    state = %{
      network_id: network_id,
      current_invocation: nil,
      genesis_invocation: nil,
      user: nil,
      processing_ref: nil,
      watchers: [],
      archival_timer: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:start_run, prompt, user}, _from, state) do
    # Get the network first to check lockout
    network = Ash.get!(Engine.Network, state.network_id, actor: user)

    # Check for lockout period
    if under_lockout?(state, network) do
      {:reply, {:lockout, state.genesis_invocation}, state}
    else
      # If we're currently processing, create genesis immediately and schedule restart
      if state.current_invocation do
        case Engine.prepare_first(network, prompt, actor: user) do
          {:ok, invocation} ->
            case Engine.start_run(invocation, actor: user) do
              {:ok, genesis_invocation} ->
                # Make the genesis visible immediately via about_to_invoke
                Engine.about_to_invoke!(genesis_invocation, actor: user)

                # Schedule the actual restart to replace current run
                Process.send_after(self(), {:restart_run, genesis_invocation, user}, 0)

                {:reply, {:ok, genesis_invocation}, state}

              {:error, reason} ->
                {:reply, {:error, reason}, state}
            end

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
      else
        # No current run, start immediately as before
        new_state = cancel_current_run(state)
        watchers = vestaboard_watchers(network)

        case Engine.prepare_first(network, prompt, actor: user) do
          {:ok, invocation} ->
            case Engine.start_run(invocation, actor: user) do
              {:ok, genesis_invocation} ->
                ref = Process.send_after(self(), :process_invocation, 0)

                new_state = %{
                  new_state
                  | current_invocation: invocation,
                    genesis_invocation: genesis_invocation,
                    user: user,
                    processing_ref: ref,
                    watchers: watchers
                }

                {:reply, {:ok, genesis_invocation}, new_state}

              {:error, reason} ->
                {:reply, {:error, reason}, new_state}
            end

          {:error, reason} ->
            {:reply, {:error, reason}, new_state}
        end
      end
    end
  end

  @impl true
  def handle_call(:stop_run, _from, state) do
    new_state = cancel_current_run(state)
    {:reply, {:ok, :stopped}, new_state}
  end

  @impl true
  def handle_info(:process_invocation, state) do
    if state.current_invocation do
      # Update state for genesis invocation
      if state.current_invocation.sequence_number == 0 do
        Engine.about_to_invoke!(state.current_invocation, actor: state.user)
      end

      # Process the invocation
      case Engine.about_to_invoke(state.current_invocation, actor: state.user) do
        {:ok, invocation} ->
          # Dispatch any watchers that should fire for this invocation based on input
          maybe_dispatch_watchers(invocation, state.watchers, state.user)

          # Continue with invocation processing
          with {:ok, invocation} <- Engine.invoke(invocation, actor: state.user),
               {:ok, next_invocation} <- Engine.prepare_next(invocation, actor: state.user) do
            # Handle archiving for image/audio outputs
            model = Panic.Model.by_id!(invocation.model)

            archival_timer =
              if model.output_type in [:image, :audio] do
                # Cancel any previous archival timer
                if state.archival_timer do
                  Process.cancel_timer(state.archival_timer)
                end

                # Schedule archival for later (delay by 5 minutes)
                Process.send_after(self(), {:archive_invocation, invocation, next_invocation}, to_timeout(minute: 5))
              else
                state.archival_timer
              end

            # Schedule next invocation
            ref = Process.send_after(self(), :process_invocation, 0)

            new_state = %{
              state
              | current_invocation: next_invocation,
                processing_ref: ref,
                archival_timer: archival_timer
            }

            {:noreply, new_state}
          else
            {:error, reason} ->
              Logger.error("Failed to process invocation: #{inspect(reason)}")

              # Instead of retrying, restart the entire run with the original prompt
              genesis = state.genesis_invocation
              original_prompt = genesis && genesis.input

              # Clear current state
              new_state = %{state | current_invocation: nil, processing_ref: nil, genesis_invocation: nil}

              # Restart the run with the original prompt after a short delay
              if original_prompt do
                Process.send_after(self(), {:restart_run, original_prompt, state.user}, 2000)
              end

              {:noreply, new_state}
          end

        {:error, reason} ->
          Logger.error("Failed to process invocation: #{inspect(reason)}")

          # Same error handling - restart with original prompt
          genesis = state.genesis_invocation
          original_prompt = genesis && genesis.input

          # Clear current state
          new_state = %{state | current_invocation: nil, processing_ref: nil, genesis_invocation: nil}

          # Restart the run with the original prompt after a short delay
          if original_prompt do
            Process.send_after(self(), {:restart_run, original_prompt, state.user}, 2000)
          end

          {:noreply, new_state}
      end
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:restart_run, genesis_invocation, user}, state) do
    # Cancel any existing run first
    new_state = cancel_current_run(state)

    # Get vestaboard watchers
    watchers = vestaboard_watchers(Ash.get!(Engine.Network, state.network_id, actor: user))

    # Use the existing genesis invocation that was already created
    ref = Process.send_after(self(), :process_invocation, 0)

    new_state = %{
      new_state
      | current_invocation: genesis_invocation,
        genesis_invocation: genesis_invocation,
        user: user,
        processing_ref: ref,
        watchers: watchers
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:archive_invocation, invocation, next_invocation}, state) do
    # Spawn the archival work asynchronously to avoid blocking
    Task.start(fn ->
      archive_invocation(invocation, next_invocation)
    end)

    # Clear the timer reference since it fired
    {:noreply, %{state | archival_timer: nil}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private functions

  defp under_lockout?(%{genesis_invocation: nil}, _network), do: false

  defp under_lockout?(%{genesis_invocation: genesis}, network) do
    lockout_seconds = network.lockout_seconds
    DateTime.diff(DateTime.utc_now(), genesis.inserted_at, :second) < lockout_seconds
  end

  defp cancel_current_run(state) do
    # Cancel processing timer
    if state.processing_ref do
      Process.cancel_timer(state.processing_ref)
    end

    # Cancel archival timer
    if state.archival_timer do
      Process.cancel_timer(state.archival_timer)
    end

    # Cancel the current invocation - do this safely to avoid timeouts
    if state.current_invocation do
      # AIDEV-NOTE: Use Task.start to avoid blocking the GenServer call
      Task.start(fn ->
        try do
          Engine.cancel!(state.current_invocation, authorize?: false)
        rescue
          error ->
            Logger.warning("Failed to cancel invocation: #{inspect(error)}")
        end
      end)
    end

    %{
      state
      | current_invocation: nil,
        processing_ref: nil,
        watchers: []
    }
  end

  # ---------------------------------------------------------------------------
  # Watcher support
  # ---------------------------------------------------------------------------

  defp vestaboard_watchers(network) do
    # Ensure installations are loaded (skip auth checks – we already authorized the network)
    network = Ash.load!(network, :installations, authorize?: false)

    Enum.flat_map(network.installations || [], fn installation ->
      Enum.filter(installation.watchers, &(&1.type == :vestaboard))
    end)
  end

  defp maybe_dispatch_watchers(%{sequence_number: seq, input: input} = _inv, watchers, user)
       when is_list(watchers) and is_binary(input) do
    Enum.each(watchers, fn watcher ->
      case watcher.type do
        :vestaboard ->
          %{stride: stride, offset: offset, name: name} = watcher

          if rem(seq, stride) == offset do
            board_name = Atom.to_string(name)
            token = Vestaboard.token_for_board!(board_name, user)

            case Vestaboard.send_text(input, token, board_name) do
              {:ok, _id} ->
                :ok

              {:error, _reason} ->
                # error message has already been logged, so no need to re-log it
                :ok
            end
          end

        :single ->
          # Single watchers could be handled here in the future
          # %{stride: stride, offset: offset} = watcher
          # Logic for single watcher dispatch would go here
          :ok

        :grid ->
          # Grid watchers could be handled here in the future
          # %{rows: rows, columns: columns} = watcher
          # Logic for grid watcher dispatch would go here
          :ok

        _ ->
          :ok
      end
    end)
  end

  defp maybe_dispatch_watchers(_inv, _watchers, _user), do: :ok

  defp archive_invocation(invocation, next_invocation) do
    case download_file(invocation.output) do
      {:ok, temp_file_path} ->
        case convert_file(temp_file_path, "invocation-#{invocation.id}-output") do
          {:ok, converted_file_path} ->
            case upload_to_s3(converted_file_path) do
              {:ok, url} ->
                Engine.update_output!(invocation, url, authorize?: false)
                Engine.update_input!(next_invocation, url, authorize?: false)
                File.rm(converted_file_path)
                :ok

              {:error, reason} ->
                Logger.error("Failed to upload to S3: #{inspect(reason)}")
                File.rm(converted_file_path)
            end

          {:error, reason} ->
            Logger.error("Failed to convert file: #{inspect(reason)}")
            File.rm(temp_file_path)
        end

      {:error, reason} ->
        Logger.error("Failed to download file: #{inspect(reason)}")
    end
  end

  defp download_file(url) do
    temp_file_path = Path.join(System.tmp_dir!(), Path.basename(url))

    case Req.get(url: url) do
      {:ok, %Req.Response{body: body, status: status}} when status in 200..299 ->
        File.write!(temp_file_path, body)
        {:ok, temp_file_path}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp convert_file(filename, dest_rootname) do
    extension = Path.extname(filename)

    case String.downcase(extension) do
      ext when ext in [".webp", ".webm"] ->
        {:ok, filename}

      ext when ext in [".jpg", ".jpeg", ".png"] ->
        output_filename = "#{Path.dirname(filename)}/#{dest_rootname}.webp"

        case System.cmd("convert", [
               filename,
               "-quality",
               "75",
               "-define",
               "webp:lossless=false",
               "-define",
               "webp:method=4",
               output_filename
             ]) do
          {_, 0} -> {:ok, output_filename}
          {error, _} -> {:error, "Image conversion failed: #{error}"}
        end

      ext when ext in [".mp3", ".wav", ".ogg", ".flac"] ->
        output_filename = "#{Path.dirname(filename)}/#{dest_rootname}.mp3"

        case System.cmd("ffmpeg", [
               "-i",
               filename,
               "-c:a",
               "libmp3lame",
               "-b:a",
               "64k",
               "-loglevel",
               "error",
               output_filename
             ]) do
          {_, 0} -> {:ok, output_filename}
          {error, _} -> {:error, "Audio conversion failed: #{error}"}
        end

      _ ->
        {:error, "Unsupported file format: #{extension}"}
    end
  end

  defp upload_to_s3(file_path) do
    bucket = "panic-invocation-outputs"
    key = Path.basename(file_path)
    body = File.read!(file_path)

    req = ReqS3.attach(Req.new())

    case Req.put(req, url: "s3://#{bucket}/#{key}", body: body) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        {:ok, "https://fly.storage.tigris.dev/#{bucket}/#{key}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
