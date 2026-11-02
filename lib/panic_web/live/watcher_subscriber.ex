defmodule PanicWeb.WatcherSubscriber do
  @moduledoc """
  Keeps a LiveView's `:invocations` stream following a network's run.

  As an `on_mount` hook (`on_mount PanicWeb.WatcherSubscriber`) it finds the
  network from the route (`network_id`, or an installation's `id`), subscribes
  to its broadcasts, and attaches a `handle_info` hook that handles them, so the
  LiveView needs no boilerplate. A LiveView that authorises its viewer some
  other way calls `watch/2` instead. Once it knows its display, the LiveView
  calls `configure_invocation_stream/4`.

  A display is `{:grid, rows, columns}` or `{:single, offset, stride,
  show_invoking}`: a single screen shows the invocations whose sequence number
  is `offset` modulo `stride`, only once they've completed unless
  `show_invoking`.

  The hook also keeps `:current_invocation` (the run's furthest invocation) and
  the network's run state assigned, follows an installation to a new network,
  and tracks each viewer's presence (see `list_viewers/1`).

  A LiveView that needs every invocation of the network, not just those its
  display shows (say, to summarise the run), implements the optional
  `c:handle_invocation/2` callback, which gets each broadcast invocation after
  the stream is updated.
  """

  alias Panic.Engine.Invocation
  alias Panic.Engine.Network
  alias PanicWeb.Presence
  alias Phoenix.Component
  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket
  alias Phoenix.Socket.Broadcast

  @callback handle_invocation(Invocation.t(), Socket.t()) ::
              Socket.t()
  @optional_callbacks handle_invocation: 2

  @doc """
  Subscribes to the route's network, if the viewer can read it. The stream is
  configured later, by the LiveView, once it knows its display.
  """
  def on_mount(:default, params, _session, socket) do
    case fetch_network_from_params(params, socket.assigns) do
      {:ok, network} ->
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

      {:error, _} ->
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

  A grid can hold back its last `:reserved_cells` (default 0) for something
  else, and its outputs then rotate through the cells before them.

  A grid can also be one screen of a larger grid spread across several:
  `:span` is `{first, total}`, the larger grid's cell this screen starts at and
  how many cells it has in all. Outputs rotate through the larger grid, and
  this screen shows the ones that land on its cells (default `{0, cells}`, a
  grid of its own).
  """
  def configure_invocation_stream(socket, %Network{} = network, display, opts \\ []) do
    slots = slots(display) - Keyword.get(opts, :reserved_cells, 0)
    {first, total} = Keyword.get(opts, :span) || {0, slots}
    span = {first, slots, total}

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
      |> LiveView.stream_configure(:invocations, dom_id: &dom_id(&1, display, span))
      |> LiveView.stream(:invocations, [])
      |> Component.assign(
        network: network,
        display: display,
        grid_span: span,
        genesis_invocation: genesis(network.current_run_number),
        latest_sequence: nil,
        network_id: network.id
      )
      |> show_current_run(network, display, total)
    end
  end

  # A display that opens mid-run (say a kiosk reloading after a deploy) shows
  # what it would have shown had it been watching all along, rather than
  # nothing until its next turn comes round.
  defp show_current_run(socket, %Network{current_run_number: nil}, _display, _cells), do: socket

  # `cells` is how many invocations back to look: a whole stride, or a whole
  # grid (across all its screens)
  defp show_current_run(socket, network, display, cells) do
    recent =
      [
        query: [
          filter: [
            network_id: network.id,
            run_number: network.current_run_number,
            state: :completed
          ],
          sort: [sequence_number: :desc],
          limit: cells
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
          [] when offset == 0 -> show_genesis(socket)
          [] -> socket
          shown -> handle_non_genesis_invocation(socket, List.last(shown), display)
        end
    end
  end

  defp slots({:grid, rows, cols}), do: rows * cols
  defp slots({:single, _offset, stride, _show_invoking}), do: stride

  # A new run starts on the first single screen, and on the grid screen with
  # the first cell; the other screens go blank until their first output,
  # rather than all repeating it.
  defp genesis_cells(_genesis, {:single, offset, _stride, _show_invoking}, _span) when offset != 0, do: []

  defp genesis_cells(_genesis, {:grid, _rows, _cols}, {first, _slots, _total}) when first != 0, do: []

  defp genesis_cells(genesis, _display, _span), do: [genesis]

  defp show_genesis(%{assigns: %{genesis_invocation: %Invocation{} = genesis}} = socket),
    do: LiveView.stream_insert(socket, :invocations, genesis)

  defp show_genesis(socket), do: socket

  # Archiving rewrites a URL the display already shows (with these actions),
  # and an invocation waiting to start has nothing to show yet
  defp handle_invocation_message(%Broadcast{event: event, payload: %{data: invocation}}, socket) do
    cond do
      not stream_configured?(socket) -> socket
      event in ["update_output", "update_input"] or waiting?(invocation) -> socket
      true -> show_invocation(invocation, socket, socket.assigns.display)
    end
  end

  defp waiting?(%Invocation{state: :ready, sequence_number: seq}), do: seq > 0
  defp waiting?(_invocation), do: false

  # a genesis starts a new run; anything else belongs to the current run (or,
  # for a display that hasn't seen one, the run it's from), or is stale
  defp show_invocation(%Invocation{sequence_number: 0} = invocation, socket, display) do
    socket
    |> Component.assign(genesis_invocation: invocation, latest_sequence: nil)
    |> track_latest(invocation)
    |> LiveView.stream(:invocations, genesis_cells(invocation, display, socket.assigns.grid_span), reset: true)
  end

  defp show_invocation(%Invocation{run_number: run_number} = invocation, socket, display) do
    case socket.assigns[:genesis_invocation] || genesis(run_number) do
      %Invocation{run_number: ^run_number} = genesis ->
        socket
        |> Component.assign(genesis_invocation: genesis)
        |> handle_non_genesis_invocation(invocation, display)

      _ ->
        socket
    end
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

  # an installation switched to another network takes its displays with it
  defp handle_installation_update_message(message, socket) do
    installation = message.payload.data
    current_network = socket.assigns[:network]

    if current_network && installation.network_id != current_network.id do
      case fetch_network(installation.network_id, socket.assigns) do
        {:ok, new_network} ->
          if LiveView.connected?(socket) do
            Presence.untrack(
              self(),
              "invocation:#{current_network.id}",
              socket.id
            )

            PanicWeb.Endpoint.unsubscribe("invocation:#{current_network.id}")
            PanicWeb.Endpoint.subscribe("invocation:#{new_network.id}")

            if socket.assigns[:display] do
              track_presence(socket, new_network.id, socket.assigns.display)
            end
          end

          socket
          |> Component.assign(network: new_network, network_id: new_network.id)
          |> maybe_reset_stream_for_network_change()

        {:error, _} ->
          socket
      end
    else
      socket
    end
  end

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
          new_socket = handle_invocation_message(msg, socket)

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
          {:halt, handle_installation_update_message(msg, socket)}

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
        fetch_network_from_installation(installation_id, assigns)

      _ ->
        {:error, :no_network_context}
    end
  end

  defp fetch_network(id, assigns), do: Panic.Engine.get_network(id, actor: assigns[:current_user])

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

  defp dom_id(%Invocation{sequence_number: seq}, {:grid, _rows, _cols}, {first, _slots, total}) do
    "slot-#{Integer.mod(seq, total) - first}"
  end

  defp dom_id(%Invocation{sequence_number: seq}, {:single, offset, stride, _show_invoking}, _span) do
    if rem(seq, stride) == offset, do: "slot-#{offset}"
  end

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

  # a run's number is its genesis invocation's id
  defp genesis(nil), do: nil

  defp genesis(run_number) do
    case Panic.Engine.get_invocation(run_number, authorize?: false) do
      {:ok, genesis} -> genesis
      {:error, _} -> nil
    end
  end

  defp handle_non_genesis_invocation(socket, invocation, display) do
    case {invocation, display} do
      # every screen of a grid tracks the latest output, so they dim alike
      {_, {:grid, _rows, _cols}} ->
        socket = track_latest(socket, invocation)

        if on_screen?(invocation, socket.assigns.grid_span),
          do: LiveView.stream_insert(socket, :invocations, invocation, at: -1),
          else: socket

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

  defp on_screen?(%Invocation{sequence_number: seq}, {first, slots, total}),
    do: Integer.mod(seq, total) in first..(first + slots - 1)//1

  # a grid dims each output by how far it is behind the latest completed one
  defp track_latest(socket, %Invocation{state: :completed, sequence_number: seq}) do
    Component.update(socket, :latest_sequence, &max(&1 || seq, seq))
  end

  defp track_latest(socket, _invocation), do: socket

  defp maybe_reset_stream_for_network_change(socket) do
    if stream_configured?(socket) do
      socket
      |> LiveView.stream(:invocations, [], reset: true)
      |> Component.assign(genesis_invocation: nil, latest_sequence: nil)
    else
      socket
    end
  end
end
