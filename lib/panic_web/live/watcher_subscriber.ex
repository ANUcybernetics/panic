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

  ## Every invocation

  A LiveView that needs every invocation of the network, not just those its
  display shows (say, to summarise the run), implements the optional
  `c:handle_invocation/2` callback, which gets each broadcast invocation after
  the stream is updated.

  ## Single Display Format

  Single display tuples are `{:single, offset, stride, show_invoking}` where
  show_invoking is a boolean. When false, invocations in the `:invoking` state
  are filtered out. The legacy 3-tuple form `{:single, offset, stride}` is
  normalised to `{:single, offset, stride, false}` at entry.
  """

  alias Panic.Engine.Invocation
  alias Panic.Engine.Network
  # ---------------------------------------------------------------------------
  # on_mount hook
  # ---------------------------------------------------------------------------
  alias PanicWeb.Presence
  alias Phoenix.Component
  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket
  alias Phoenix.Socket.Broadcast

  @callback handle_invocation(Invocation.t(), Socket.t()) ::
              Socket.t()
  @optional_callbacks handle_invocation: 2

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
          |> Component.assign(
            installation_id: installation_id,
            network_id: network.id,
            watching: network.id
          )

        {:cont, socket}

      # ---------------------------------------------------------------------------
      # Manual helpers (kept for backwards-compat)
      # ---------------------------------------------------------------------------

      {:error, _} ->
        # No network context: continue without attaching the watcher
        {:cont, socket}
    end
  end

  @doc """
  Subscribes `socket` to `network`'s broadcasts and attaches the hook that
  handles them, as `on_mount/4` does when the viewer can read the network. A
  LiveView that authorises its viewer some other way (the anonymous terminal's
  token) calls this once it has. Does nothing if it's already watching.
  """
  def watch(%{assigns: %{watching: id}} = socket, %Network{id: id}), do: socket

  def watch(socket, %Network{} = network) do
    socket
    |> maybe_subscribe(network, nil)
    |> attach_invocation_hook()
    |> Component.assign(network_id: network.id, watching: network.id)
  end

  @doc """
  Configure the `:invocations` stream on `socket`.

  Idempotent – if the stream is already configured it does nothing.
  Also tracks presence for this LiveView.
  """
  def configure_invocation_stream(socket, %Network{} = network, display) do
    display = normalise_display(display)

    if stream_configured?(socket) do
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
        genesis_invocation: current_genesis(network),
        network_id: network.id
      )
      |> show_current_run(network, display)
    end
  end

  # A display that opens mid-run (say a kiosk reloading after a deploy) shows
  # what it would have shown had it been watching all along, rather than
  # nothing until its next turn comes round.
  defp show_current_run(socket, %Network{current_run_number: nil}, _display), do: socket

  defp show_current_run(socket, network, display) do
    recent =
      [
        query: [
          filter: [
            network_id: network.id,
            run_number: network.current_run_number,
            state: :completed
          ],
          sort: [sequence_number: :desc],
          limit: slots(display)
        ],
        authorize?: false
      ]
      |> Panic.Engine.list_invocations!()
      |> Enum.reverse()

    case display do
      {:grid, _rows, _cols} ->
        Enum.reduce(recent, socket, &handle_non_genesis_invocation(&2, &1, display))

      {:single, offset, stride, _show_invoking} ->
        case Enum.filter(
               recent,
               &(rem(&1.sequence_number, stride) == offset and &1.sequence_number > 0)
             ) do
          [] -> show_genesis(socket)
          shown -> handle_non_genesis_invocation(socket, List.last(shown), display)
        end
    end
  end

  defp slots({:grid, rows, cols}), do: rows * cols
  defp slots({:single, _offset, stride, _show_invoking}), do: stride

  defp show_genesis(%{assigns: %{genesis_invocation: %Invocation{} = genesis}} = socket),
    do: LiveView.stream_insert(socket, :invocations, genesis)

  defp show_genesis(socket), do: socket

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
        if stream_configured?(socket) do
          display = socket.assigns.display
          invocation = message.payload.data

          # Archiving rewrites a URL the display already shows, and an
          # invocation waiting to start has nothing to show yet
          if should_filter_archive_url?(invocation) or waiting?(invocation) do
            {:noreply, socket}
          else
            handle_filtered_invocation_message(invocation, socket, display)
          end
        else
          {:noreply, socket}
        end
    end
  end

  defp waiting?(%Invocation{state: :ready, sequence_number: seq}), do: seq > 0
  defp waiting?(_invocation), do: false

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

  defp normalise_display({:single, offset, stride}), do: {:single, offset, stride, false}
  # ---------------------------------------------------------------------------
  # Internal helpers
  # ---------------------------------------------------------------------------
  # Also subscribe to installation updates if we're in installation mode
  defp normalise_display(display), do: display

  defp maybe_subscribe(socket, network, installation_id) do
    if LiveView.connected?(socket) do
      PanicWeb.Endpoint.subscribe("invocation:#{network.id}")
      PanicWeb.Endpoint.subscribe("network:#{network.id}")

      if installation_id do
        PanicWeb.Endpoint.subscribe("installation:#{installation_id}")
      end
    end

    socket
  end

  defp track_presence(socket, network_id, display) do
    if LiveView.connected?(socket) do
      Presence.track(
        self(),
        "invocation:#{network_id}",
        socket.id,
        presence_metadata(socket, display)
      )
    end
  end

  defp update_presence(socket, network_id, display) do
    if LiveView.connected?(socket) do
      Presence.update(
        self(),
        "invocation:#{network_id}",
        socket.id,
        presence_metadata(socket, display)
      )
    end
  end

  defp stream_configured?(socket) do
    Map.has_key?(socket.assigns[:streams] || %{}, :invocations)
  end

  defp presence_metadata(socket, display) do
    user = socket.assigns[:current_user]

    %{
      display: display,
      user_id: user && user.id,
      user_email: user && user.email,
      installation_id: socket.assigns[:installation_id],
      watcher_name: socket.assigns[:watcher_name],
      joined_at: DateTime.utc_now()
    }
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
                new_socket
                |> Component.assign(
                  :current_invocation,
                  latest(new_socket.assigns[:current_invocation], invocation)
                )
                |> notify_view(invocation)

              _ ->
                new_socket
            end

          {:halt, new_socket}

        %Broadcast{topic: "installation:" <> _} = msg, socket ->
          {:noreply, new_socket} = handle_installation_update_message(msg, socket)
          {:halt, new_socket}

        %Broadcast{topic: "network:" <> _, payload: %{data: %Network{} = updated}}, socket ->
          {:halt, assign_run_state(socket, updated)}

        _other, socket ->
          {:cont, socket}
      end
    )
  end

  defp notify_view(socket, invocation) do
    if function_exported?(socket.view, :handle_invocation, 2),
      do: socket.view.handle_invocation(invocation, socket),
      else: socket
  end

  defp fetch_network_from_params(params, assigns) do
    case params do
      %{"network_id" => network_id} ->
        fetch_network(network_id, assigns)

      %{"id" => installation_id} ->
        # This is an installation route - fetch network via installation
        fetch_network_from_installation(installation_id, assigns)

      # NOTE: We no longer derive display mode at `on_mount` time, as the LiveView
      # will explicitly call `configure_invocation_stream/3` once it knows which
      # display variant it wants.
      _ ->
        {:error, :no_network_context}
    end
  end

  defp fetch_network(id, assigns) do
    # ---------------------------------------------------------------------------
    # DOM helpers
    # ---------------------------------------------------------------------------
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

  defp dom_id(%Invocation{sequence_number: seq}, {:grid, rows, cols}) do
    "slot-#{Integer.mod(seq, rows * cols)}"
  end

  # Genesis invocations (seq 0) must render in all single-mode watchers, not just
  # offset 0. Without this clause, rem(0, stride) == offset is false for offset > 0,
  # producing a nil dom_id that silently prevents the "P!" screen from appearing.
  defp dom_id(%Invocation{sequence_number: 0}, {:single, offset, _stride, _show_invoking}) do
    "slot-#{offset}"
  end

  defp dom_id(%Invocation{sequence_number: seq}, {:single, offset, stride, _show_invoking}) do
    if rem(seq, stride) == offset, do: "slot-#{offset}"
  end

  # ---------------------------------------------------------------------------
  # Genesis invocation handling
  # ---------------------------------------------------------------------------

  # Broadcasts from one transaction can arrive in any order (a completed
  # invocation and the next one it created), so the current invocation is the
  # furthest along: the latest run, then the highest sequence number.
  defp latest(%Invocation{} = current, %Invocation{} = new) do
    if {new.run_number || 0, new.sequence_number} >=
         {current.run_number || 0, current.sequence_number},
       do: new,
       else: current
  end

  defp latest(_current, new), do: new

  # Keeps the run fields (and the anonymous terminal setting, which decides
  # whether a display shows its QR code) of the assigned network current,
  # without replacing whatever relationships the LiveView loaded on it.
  defp assign_run_state(socket, %Network{} = updated) do
    case socket.assigns[:network] do
      %Network{id: id} = network when id == updated.id ->
        run_state =
          Map.take(updated, [:current_run_number, :run_started_at, :anon_terminal_minutes])

        Component.assign(socket, :network, Map.merge(network, run_state))

      _ ->
        socket
    end
  end

  defp current_genesis(%Network{current_run_number: nil}), do: nil

  defp current_genesis(%Network{current_run_number: run_number}) do
    case Panic.Engine.get_invocation(run_number, authorize?: false) do
      {:ok, genesis} -> genesis
      {:error, _} -> nil
    end
  end

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
        # every invocation a single watcher shows has the same dom id, so this
        # replaces the one on screen (a stream limit would count #display-info
        # and remove it instead)
        if show_invoking or state != :invoking do
          LiveView.stream_insert(socket, :invocations, invocation, at: 0)
        else
          socket
        end

      {_, {:single, _, _, _}} ->
        socket
    end
  end

  defp maybe_reset_stream_for_network_change(socket) do
    # Reset the invocation stream if it's configured
    if stream_configured?(socket) do
      socket
      |> LiveView.stream(:invocations, [], reset: true)
      |> Component.assign(genesis_invocation: nil)
    else
      socket
    end
  end
end
