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
  - **Retry with Exponential Backoff**: Failed invocations are retried with exponential backoff (1s, 2s, 4s, 8s, 16s)

  ## State Management

  The GenServer maintains the following state:
  - `network_id`: The ID of the network being processed
  - `current_invocation`: The invocation currently being processed
  - `genesis_invocation`: The first invocation of the current run
  - `user`: The user who started the current run
  - `processing_ref`: Timer reference for the next processing cycle
  - `retry_count`: Number of retry attempts for the current invocation
  - `max_retries`: Maximum number of retries (default: 5)

  ## Configuration

  The following configuration options are available:

  - `:lockout_seconds` - Time in seconds between genesis invocations (default: 30)
  - `:network_runner_max_retries` - Maximum number of retry attempts for failed invocations (default: 5)

  Example configuration:

      config :panic,
        lockout_seconds: 30,
        network_runner_max_retries: 5

  ## Testing Considerations

  # AIDEV-NOTE: NetworkRunner persists across tests; requires cleanup in test setup
  NetworkRunner GenServers persist in the NetworkRegistry across test runs and maintain
  user state. This can cause Ash.Error.Forbidden when stale processes run with wrong
  actor context. Use PanicWeb.Helpers.stop_all_network_runners/0 in test setup.
  """

  use GenServer

  alias Panic.Engine
  alias Panic.Engine.NetworkRegistry
  alias Panic.Model
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
      retry_count: 0,
      watchers: [],
      max_retries: Application.get_env(:panic, :network_runner_max_retries, 5)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:start_run, prompt, user}, _from, state) do
    # Check for lockout period
    if under_lockout?(state) do
      {:reply, {:lockout, state.genesis_invocation}, state}
    else
      # Cancel any existing run
      new_state = cancel_current_run(state)

      # Get the network and vestaboard watchers
      network = Ash.get!(Engine.Network, state.network_id, actor: user)
      watchers = vestaboard_watchers(network)

      # Create the first invocation
      case Engine.prepare_first(network, prompt, actor: user) do
        {:ok, invocation} ->
          # Start the run
          case Engine.start_run(invocation, actor: user) do
            {:ok, genesis_invocation} ->
              # Start processing
              ref = Process.send_after(self(), :process_invocation, 0)

              new_state = %{
                new_state
                | current_invocation: invocation,
                  genesis_invocation: genesis_invocation,
                  user: user,
                  processing_ref: ref,
                  retry_count: 0,
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
      with {:ok, invocation} <- Engine.about_to_invoke(state.current_invocation, actor: state.user),
           {:ok, invocation} <- Engine.invoke(invocation, actor: state.user),
           {:ok, next_invocation} <- Engine.prepare_next(invocation, actor: state.user) do
        # Handle archiving for image/audio outputs
        model = Panic.Model.by_id!(invocation.model)

        if model.output_type in [:image, :audio] do
          Task.start(fn ->
            archive_invocation(invocation, next_invocation)
          end)
        end

        # Dispatch any Vestaboard watchers that should fire for this invocation
        maybe_dispatch_vestaboard(invocation, state.watchers, state.user)

        # Schedule next invocation
        ref = Process.send_after(self(), :process_invocation, 0)

        new_state = %{state | current_invocation: next_invocation, processing_ref: ref, retry_count: 0}
        {:noreply, new_state}
      else
        {:error, reason} ->
          if state.retry_count < state.max_retries do
            # Calculate exponential backoff: 2^retry_count * 1000ms (1s, 2s, 4s, 8s, 16s)
            delay = round(:math.pow(2, state.retry_count) * 1000)

            Logger.warning(
              "Failed to process invocation (attempt #{state.retry_count + 1}/#{state.max_retries + 1}), " <>
                "retrying in #{delay}ms: #{inspect(reason)}"
            )

            # Schedule retry with exponential backoff
            ref = Process.send_after(self(), :retry_invocation, delay)

            new_state = %{state | processing_ref: ref, retry_count: state.retry_count + 1}
            {:noreply, new_state}
          else
            Logger.error("Failed to process invocation after #{state.max_retries + 1} attempts: #{inspect(reason)}")
            # Clear the current invocation after exhausting retries
            {:noreply, %{state | current_invocation: nil, processing_ref: nil, retry_count: 0}}
          end
      end
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:retry_invocation, state) do
    # Retry the current invocation
    send(self(), :process_invocation)
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private functions

  defp under_lockout?(%{genesis_invocation: nil}), do: false

  defp under_lockout?(%{genesis_invocation: genesis}) do
    lockout_seconds = Application.get_env(:panic, :lockout_seconds, 30)
    DateTime.diff(DateTime.utc_now(), genesis.inserted_at, :second) < lockout_seconds
  end

  defp cancel_current_run(state) do
    # Cancel the processing timer
    if state.processing_ref do
      Process.cancel_timer(state.processing_ref)
    end

    # Cancel the current invocation
    if state.current_invocation do
      Engine.cancel!(state.current_invocation, authorize?: false)
    end

    %{
      state
      | current_invocation: nil,
        processing_ref: nil,
        retry_count: 0,
        watchers: []
    }
  end

  # ---------------------------------------------------------------------------
  # Vestaboard watcher support
  # ---------------------------------------------------------------------------

  defp vestaboard_watchers(network) do
    # Ensure installations are loaded (skip auth checks – we already authorized the network)
    network = Ash.load!(network, :installations, authorize?: false)

    Enum.flat_map(network.installations || [], fn installation ->
      Enum.filter(installation.watchers, &(&1.type == :vestaboard))
    end)
  end

  defp maybe_dispatch_vestaboard(%{sequence_number: seq, output: output} = _inv, watchers, user)
       when is_list(watchers) and is_binary(output) do
    Enum.each(watchers, fn %{stride: stride, offset: offset, name: name} = _watcher ->
      if rem(seq, stride) == offset do
        board_id = "vestaboard-#{name |> Atom.to_string() |> String.replace("_", "-")}"
        model = Model.by_id!(board_id)
        token = Vestaboard.token_for_model!(model, user)

        case Vestaboard.send_text(model, output, token) do
          {:ok, _id} ->
            :ok

          {:error, reason} ->
            Logger.warning("Vestaboard dispatch failed for #{name}: #{inspect(reason)}")
        end
      end
    end)
  end

  defp maybe_dispatch_vestaboard(_inv, _watchers, _user), do: :ok

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
