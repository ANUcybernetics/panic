defmodule Panic.Engine.NetworkProcessor do
  @moduledoc """
  A GenServer that processes invocations for a specific network.

  Handles recursive invocation processing, lockout periods, and archiving.

  This GenServer replaces the previous Oban-based invocation processing system.
  Each network gets its own NetworkProcessor GenServer that is started on demand
  and registered via the NetworkRegistry.

  ## Key Features

  - **Recursive Processing**: Automatically processes invocations in sequence until stopped
  - **Lockout Period**: Enforces a 30-second lockout between genesis invocations
  - **Automatic Archiving**: Archives image/audio outputs to S3-compatible storage
  - **Graceful Cancellation**: Supports stopping runs in progress

  ## State Management

  The GenServer maintains the following state:
  - `network_id`: The ID of the network being processed
  - `current_invocation`: The invocation currently being processed
  - `genesis_invocation`: The first invocation of the current run
  - `user`: The user who started the current run
  - `processing_ref`: Timer reference for the next processing cycle
  """

  use GenServer

  alias Panic.Engine
  alias Panic.Engine.NetworkRegistry

  require Logger

  # Client API

  @doc """
  Starts a NetworkProcessor for the given network.

  The processor is registered in the NetworkRegistry under the network_id.

  ## Options

    * `:network_id` - Required. The ID of the network to process

  ## Examples

      iex> NetworkProcessor.start_link(network_id: 123)
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
  1. Start a NetworkProcessor if one isn't already running
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

      iex> NetworkProcessor.start_run(1, "Hello world", user)
      {:ok, %Invocation{...}}

      # Too soon after previous run
      iex> NetworkProcessor.start_run(1, "Another prompt", user)
      {:lockout, %Invocation{...}}
  """
  def start_run(network_id, prompt, user) do
    case Registry.lookup(NetworkRegistry, network_id) do
      [{pid, _}] ->
        GenServer.call(pid, {:start_run, prompt, user})

      [] ->
        # Start the processor if it doesn't exist
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
  processing loop. The NetworkProcessor GenServer remains alive and can
  accept new runs.

  ## Parameters

    * `network_id` - The ID of the network to stop

  ## Returns

    * `{:ok, :stopped}` - Successfully stopped the run
    * `{:ok, :not_running}` - No processor was running for this network

  ## Examples

      iex> NetworkProcessor.stop_run(1)
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
      processing_ref: nil
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

      # Get the network
      network = Ash.get!(Engine.Network, state.network_id, actor: user)

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
                  processing_ref: ref
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
        Engine.update_state!(state.current_invocation, :invoking, actor: state.user)
      end

      # Process the invocation
      with {:ok, invocation} <- Engine.about_to_invoke(state.current_invocation, actor: state.user),
           {:ok, invocation} <- Engine.invoke(invocation, actor: state.user),
           {:ok, next_invocation} <- Engine.prepare_next(invocation, actor: state.user) do
        # Handle archiving for image/audio outputs
        model = invocation.model |> List.last() |> Panic.Model.by_id!()

        if model.output_type in [:image, :audio] do
          Task.start(fn ->
            archive_invocation(invocation, next_invocation)
          end)
        end

        # Schedule next invocation
        ref = Process.send_after(self(), :process_invocation, 0)

        new_state = %{state | current_invocation: next_invocation, processing_ref: ref}
        {:noreply, new_state}
      else
        {:error, reason} ->
          Logger.error("Failed to process invocation: #{inspect(reason)}")
          # Clear the current invocation on error
          {:noreply, %{state | current_invocation: nil, processing_ref: nil}}
      end
    else
      {:noreply, state}
    end
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
        processing_ref: nil
    }
  end

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
