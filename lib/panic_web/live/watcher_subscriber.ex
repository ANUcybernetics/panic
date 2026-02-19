defmodule PanicWeb.WatcherSubscriber do
  @moduledoc ~S"""
  Helper for subscribing to and managing a stream of `%Invocation{}` structs
  inside Phoenix LiveViews using Phoenix Presence.

  It offers three public facets:

    * `on_mount/1` – a LiveView mount hook that automatically:
        • subscribes to `"invocation:<network_id>"` pub-sub topic
        • tracks the LiveView's presence for the network
        • configures the `:invocations` stream
        • attaches a `handle_info` hook so the LiveView itself needs **no**
          boilerplate for invocation broadcasts
        • assigns `current_invocation` from broadcast payloads
    * `configure_invocation_stream/3` – manual set-up (kept for
      backwards-compatibility)
    * `handle_invocation_message/2` – processes a broadcast and updates the
      stream / genesis invocation as required

  ## Phoenix Presence Integration

  This module now uses Phoenix Presence to track which LiveViews are watching
  which networks. Presence information includes:
  - Display mode (grid/single)
  - User information (if authenticated)
  - Installation ID (if viewing through an installation)

  ## Usage

  In a LiveView that receives a `network_id` param:

      defmodule MyAppWeb.SomeLive do
        use MyAppWeb, :live_view
        on_mount {PanicWeb.WatcherSubscriber, :auto}
        ...
      end

  Pass an explicit display tuple (`{:grid, rows, cols}` or `{:single, off, stride, show_invoking}`)
  instead of `:auto` if you don't want automatic detection.

  The display tuple format is also used by Installation watchers, where each watcher
  struct is converted to the appropriate display tuple format.

  ## Single Display Format

  Single display tuples are `{:single, offset, stride, show_invoking}` where
  show_invoking is a boolean. When false, invocations in the `:invoking` state
  are filtered out. The legacy 3-tuple form `{:single, offset, stride}` is
  normalised to `{:single, offset, stride, false}` at entry.
  """

  alias Panic.Engine.Invocation
  alias PanicWeb.Presence
  alias Phoenix.Component
  alias Phoenix.LiveView

  # ---------------------------------------------------------------------------
  # on_mount hook
  # ---------------------------------------------------------------------------

  alias Phoenix.Socket.Broadcast

  @doc """
  LiveView `on_mount/4` callback.

  The first argument can be `:auto` (default) to infer the display mode from the
  params & live_action, or a display tuple (`{:grid, rows, cols}` /
  `{:single, offset, stride, show_invoking}`) to force a specific mode.
  """
  def on_mount(_display_mode \\ :auto, params, _session, socket) do
    case fetch_network_from_params(params, socket.assigns) do
      {:ok, network} ->
        # Only subscribe and attach the watcher. We **do not** configure the
        # invocation stream here because the correct `display` mode is typically
        # chosen later inside the LiveView (e.g. in `handle_params/3`). Doing it
        # here caused incorrect behaviour when `socket.assigns.live_action` was
        # not yet set.
        installation_id =
          case params do
            %{"id" => id} -> id
            _ -> nil
          end

        socket =
          socket
          |> maybe_subscribe(network, installation_id)
          |> attach_invocation_hook()
          |> Component.assign(installation_id: installation_id, network_id: network.id)

        {:cont, socket}

      {:error, _} ->
        # No network context: continue without attaching the watcher
        {:cont, socket}
    end
  end

  # ---------------------------------------------------------------------------
  # Manual helpers (kept for backwards-compat)
  # ---------------------------------------------------------------------------

  @doc """
  Configure the `:invocations` stream on `socket`.

  Idempotent – if the stream is already configured it does nothing.
  Also tracks presence for this LiveView.
  """
  def configure_invocation_stream(socket, %Panic.Engine.Network{} = network, display) do
    display = normalise_display(display)

    configured? =
      socket.assigns
      |> Map.get(:streams)
      |> case do
        nil -> false
        streams -> Map.has_key?(streams, :invocations)
      end

    if configured? do
      # Stream already configured – nothing to (re)configure, just keep assigns fresh
      # But update presence metadata if display mode changed
      if socket.assigns[:display] != display do
        update_presence(socket, network.id, display)
      end

      Component.assign(socket, display: display)
    else
      # Track presence for this LiveView
      track_presence(socket, network.id, display)

      socket
      |> LiveView.stream_configure(:invocations, dom_id: &dom_id(&1, display))
      |> LiveView.stream(:invocations, [])
      |> Component.assign(
        network: network,
        display: display,
        genesis_invocation: nil,
        network_id: network.id
      )
    end
  end

  @doc """
  Handle a broadcast carrying an `%Invocation{}` and update the LiveView socket.

  Returns `{:noreply, socket}` so callers can simply `handle_invocation_message/2`.
  """
  def handle_invocation_message(message, socket) do
    # Skip non-invocation events
    case message.event do
      "presence_diff" ->
        {:noreply, socket}

      _ ->
        # Check if invocation stream is configured - if not, ignore the message
        configured? =
          socket.assigns
          |> Map.get(:streams)
          |> case do
            nil -> false
            streams -> Map.has_key?(streams, :invocations)
          end

        if configured? do
          display = socket.assigns.display
          invocation = message.payload.data

          # Filter out invocations with archive URLs
          if should_filter_archive_url?(invocation) do
            {:noreply, socket}
          else
            handle_filtered_invocation_message(invocation, socket, display)
          end
        else
          {:noreply, socket}
        end
    end
  end

  defp should_filter_archive_url?(%Invocation{input: input, output: output}) do
    archive_prefix = "https://fly.storage.tigris.dev/"

    String.starts_with?(input || "", archive_prefix) or
      String.starts_with?(output || "", archive_prefix)
  end

  defp handle_filtered_invocation_message(invocation, socket, display) do
    socket =
      case invocation do
        # Genesis invocation: reset everything and start new run
        %Invocation{sequence_number: 0} ->
          socket
          |> Component.assign(genesis_invocation: invocation)
          |> LiveView.stream(:invocations, [invocation], reset: true)

        # Non-genesis invocation: handle based on current genesis state
        %Invocation{run_number: run_number} ->
          case socket.assigns[:genesis_invocation] do
            %Invocation{run_number: ^run_number} ->
              # Same run - process the invocation
              handle_non_genesis_invocation(socket, invocation, display)

            nil ->
              # No genesis set - this is a mid-run join, fetch genesis invocation
              case fetch_genesis_invocation(invocation, socket.assigns.network) do
                {:ok, genesis} ->
                  # Set genesis and process this invocation
                  socket
                  |> Component.assign(genesis_invocation: genesis)
                  |> handle_non_genesis_invocation(invocation, display)

                {:error, _} ->
                  # Failed to fetch genesis, ignore this invocation
                  socket
              end

            _ ->
              # Different run - ignore this invocation
              socket
          end
      end

    {:noreply, socket}
  end

  @doc """
  Get the list of current viewers for a network.

  Returns a list of presence entries with metadata about each viewer.
  """
  def list_viewers(network_id) do
    "invocation:#{network_id}"
    |> Presence.list()
    |> Enum.map(fn {_id, %{metas: metas}} -> List.first(metas) end)
    |> Enum.filter(& &1)
  end

  @doc """
  Handle an installation update broadcast and switch to the new network if needed.

  Returns `{:noreply, socket}` so callers can simply use it in handle_info hooks.
  """
  def handle_installation_update_message(message, socket) do
    installation = message.payload.data
    current_network = socket.assigns[:network]

    # Check if the network has changed
    if current_network && installation.network_id != current_network.id do
      # Network changed - need to switch subscriptions
      case fetch_network(installation.network_id, socket.assigns) do
        {:ok, new_network} ->
          # Unsubscribe from old network, subscribe to new
          if LiveView.connected?(socket) do
            # Untrack presence from old network
            Presence.untrack(
              self(),
              "invocation:#{current_network.id}",
              socket.id
            )

            PanicWeb.Endpoint.unsubscribe("invocation:#{current_network.id}")
            PanicWeb.Endpoint.subscribe("invocation:#{new_network.id}")

            # Track presence for new network if display is configured
            if socket.assigns[:display] do
              track_presence(socket, new_network.id, socket.assigns.display)
            end
          end

          # Update network assignment and reset stream if configured
          socket =
            socket
            |> Component.assign(network: new_network, network_id: new_network.id)
            |> maybe_reset_stream_for_network_change()

          {:noreply, socket}

        {:error, _} ->
          # Failed to fetch new network, keep current state
          {:noreply, socket}
      end
    else
      # Network unchanged or no current network
      {:noreply, socket}
    end
  end

  # ---------------------------------------------------------------------------
  # Internal helpers
  # ---------------------------------------------------------------------------

  defp normalise_display({:single, offset, stride}), do: {:single, offset, stride, false}
  defp normalise_display(display), do: display

  defp maybe_subscribe(socket, network, installation_id) do
    if LiveView.connected?(socket) do
      PanicWeb.Endpoint.subscribe("invocation:#{network.id}")

      # Also subscribe to installation updates if we're in installation mode
      if installation_id do
        PanicWeb.Endpoint.subscribe("installation:#{installation_id}")
      end
    end

    socket
  end

  defp track_presence(socket, network_id, display) do
    if LiveView.connected?(socket) do
      user = socket.assigns[:current_user]
      installation_id = socket.assigns[:installation_id]
      watcher_name = socket.assigns[:watcher_name]

      metadata = %{
        display: display,
        user_id: user && user.id,
        user_email: user && user.email,
        installation_id: installation_id,
        watcher_name: watcher_name,
        joined_at: DateTime.utc_now()
      }

      Presence.track(
        self(),
        "invocation:#{network_id}",
        socket.id,
        metadata
      )
    end
  end

  defp update_presence(socket, network_id, display) do
    if LiveView.connected?(socket) do
      user = socket.assigns[:current_user]
      installation_id = socket.assigns[:installation_id]
      watcher_name = socket.assigns[:watcher_name]

      metadata = %{
        display: display,
        user_id: user && user.id,
        user_email: user && user.email,
        installation_id: installation_id,
        watcher_name: watcher_name,
        joined_at: DateTime.utc_now()
      }

      Presence.update(
        self(),
        "invocation:#{network_id}",
        socket.id,
        metadata
      )
    end
  end

  defp attach_invocation_hook(socket) do
    LiveView.attach_hook(
      socket,
      :invocation_watcher,
      :handle_info,
      fn
        %Broadcast{topic: "invocation:" <> _, event: "presence_diff"}, socket ->
          {:halt, socket}

        %Broadcast{topic: "invocation:" <> _} = msg, socket ->
          {:noreply, new_socket} = handle_invocation_message(msg, socket)

          new_socket =
            case msg.payload do
              %{data: %Invocation{} = invocation} ->
                Component.assign(new_socket, :current_invocation, invocation)

              _ ->
                new_socket
            end

          {:halt, new_socket}

        %Broadcast{topic: "installation:" <> _} = msg, socket ->
          {:noreply, new_socket} = handle_installation_update_message(msg, socket)
          {:halt, new_socket}

        _other, socket ->
          {:cont, socket}
      end
    )
  end

  # NOTE: We no longer derive display mode at `on_mount` time, as the LiveView
  # will explicitly call `configure_invocation_stream/3` once it knows which
  # display variant it wants.

  defp fetch_network_from_params(params, assigns) do
    case params do
      %{"network_id" => network_id} ->
        fetch_network(network_id, assigns)

      %{"id" => installation_id} ->
        # This is an installation route - fetch network via installation
        fetch_network_from_installation(installation_id, assigns)

      _ ->
        {:error, :no_network_context}
    end
  end

  defp fetch_network(id, assigns) do
    actor = Map.get(assigns, :current_user)

    case Panic.Engine.get_network(id, actor: actor) do
      {:ok, _} = ok -> ok
      {:error, _} = err -> err
    end
  end

  defp fetch_network_from_installation(installation_id, assigns) do
    actor = Map.get(assigns, :current_user)

    case Panic.Watcher.get_installation(installation_id,
           actor: actor,
           authorize?: false,
           load: [:network]
         ) do
      {:ok, installation} -> {:ok, installation.network}
      {:error, _} = err -> err
    end
  end

  # ---------------------------------------------------------------------------
  # DOM helpers
  # ---------------------------------------------------------------------------

  defp dom_id(%Invocation{sequence_number: seq}, {:grid, rows, cols}) do
    "slot-#{Integer.mod(seq, rows * cols)}"
  end

  defp dom_id(%Invocation{sequence_number: seq}, {:single, offset, stride, _show_invoking}) do
    if rem(seq, stride) == offset, do: "slot-#{offset}"
  end

  # ---------------------------------------------------------------------------
  # Genesis invocation handling
  # ---------------------------------------------------------------------------

  defp fetch_genesis_invocation(%Invocation{run_number: run_number}, _network) do
    # note: run_number is the id of the genesis invocation
    case Panic.Engine.get_invocation(run_number, authorize?: false) do
      {:ok, genesis} -> {:ok, genesis}
      {:error, _} = error -> error
    end
  end

  defp handle_non_genesis_invocation(socket, invocation, display) do
    case {invocation, display} do
      {_, {:grid, _rows, _cols}} ->
        LiveView.stream_insert(socket, :invocations, invocation, at: -1)

      {%Invocation{sequence_number: seq, state: state}, {:single, offset, stride, show_invoking}}
      when rem(seq, stride) == offset ->
        if show_invoking or state != :invoking do
          LiveView.stream_insert(socket, :invocations, invocation, at: 0, limit: 1)
        else
          socket
        end

      {_, {:single, _, _, _}} ->
        socket
    end
  end

  defp maybe_reset_stream_for_network_change(socket) do
    # Reset the invocation stream if it's configured
    if socket.assigns[:streams] && Map.has_key?(socket.assigns.streams, :invocations) do
      socket
      |> LiveView.stream(:invocations, [], reset: true)
      |> Component.assign(genesis_invocation: nil)
    else
      socket
    end
  end
end
