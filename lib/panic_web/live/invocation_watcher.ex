defmodule PanicWeb.InvocationWatcher do
  @moduledoc ~S"""
  Helper for subscribing to and managing a stream of `%Invocation{}` structs
  inside Phoenix LiveViews.

  It offers three public facets:

    * `on_mount/1` – a LiveView mount hook that automatically:
        • subscribes to `"invocation:<network_id>"` pub-sub topic
        • configures the `:invocations` stream
        • attaches a `handle_info` hook so the LiveView itself needs **no**
          boilerplate for invocation broadcasts
    * `configure_invocation_stream/3` – manual set-up (kept for
      backwards-compatibility)
    * `handle_invocation_message/2` – processes a broadcast and updates the
      stream / genesis invocation as required

  ## Usage

  In a LiveView that receives a `network_id` param:

      defmodule MyAppWeb.SomeLive do
        use MyAppWeb, :live_view
        on_mount {PanicWeb.InvocationWatcher, :auto}
        ...
      end

  Pass an explicit display tuple (`{:grid, rows, cols}` or `{:single, off, stride}`)
  instead of `:auto` if you don't want automatic detection.

  The display tuple format is also used by Installation watchers, where each watcher
  struct is converted to the appropriate display tuple format.
  """

  alias Panic.Engine.Invocation
  alias Panic.Engine.Network
  alias Phoenix.Component
  alias Phoenix.LiveView

  # ---------------------------------------------------------------------------
  # on_mount hook
  # ---------------------------------------------------------------------------

  @doc """
  LiveView `on_mount/4` callback.

  The first argument can be `:auto` (default) to infer the display mode from the
  params & live_action, or a display tuple (`{:grid, rows, cols}` /
  `{:single, offset, stride}`) to force a specific mode.
  """
  @spec on_mount(term(), map(), map(), LiveView.Socket.t()) ::
          {:cont, LiveView.Socket.t()} | {:halt, LiveView.Socket.t()}
  def on_mount(_display_mode \\ :auto, params, _session, socket) do
    with %{"network_id" => id} <- params,
         {:ok, network} <- fetch_network(id, socket.assigns) do
      # Only subscribe and attach the watcher. We **do not** configure the
      # invocation stream here because the correct `display` mode is typically
      # chosen later inside the LiveView (e.g. in `handle_params/3`). Doing it
      # here caused incorrect behaviour when `socket.assigns.live_action` was
      # not yet set.
      socket =
        socket
        |> maybe_subscribe(network)
        |> attach_invocation_hook()

      {:cont, socket}
    else
      _ ->
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
  """
  def configure_invocation_stream(socket, %Network{} = network, display) do
    configured? =
      socket.assigns
      |> Map.get(:streams)
      |> case do
        nil -> false
        streams -> Map.has_key?(streams, :invocations)
      end

    if configured? do
      # Stream already configured – nothing to (re)configure, just keep assigns fresh
      Component.assign(socket, display: display)
    else
      socket
      |> LiveView.stream_configure(:invocations, dom_id: &dom_id(&1, display))
      |> LiveView.stream(:invocations, [])
      |> Component.assign(network: network, display: display, genesis_invocation: nil)
    end
  end

  @doc """
  Handle a broadcast carrying an `%Invocation{}` and update the LiveView socket.

  Returns `{:noreply, socket}` so callers can simply `handle_invocation_message/2`.
  """
  def handle_invocation_message(message, socket) do
    display = socket.assigns.display
    invocation = message.payload.data

    socket =
      case {invocation, display} do
        {%Invocation{state: :ready}, _} ->
          socket

        {%Invocation{sequence_number: 0, state: :invoking}, {:grid, _rows, _cols}} ->
          socket
          |> update_genesis(invocation)
          |> LiveView.stream(:invocations, [invocation], reset: true)

        {_, {:grid, _rows, _cols}} ->
          socket
          |> update_genesis(invocation)
          |> LiveView.stream_insert(:invocations, invocation, at: -1)

        {%Invocation{sequence_number: seq}, {:single, offset, stride}}
        when rem(seq, stride) == offset ->
          socket
          |> LiveView.stream_insert(:invocations, invocation, at: 0, limit: 1)
          |> update_genesis(invocation)

        {_, {:single, _, _}} ->
          update_genesis(socket, invocation)

        _ ->
          socket
      end

    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Internal helpers
  # ---------------------------------------------------------------------------

  defp maybe_subscribe(socket, network) do
    if LiveView.connected?(socket) do
      PanicWeb.Endpoint.subscribe("invocation:#{network.id}")
    end

    socket
  end

  defp attach_invocation_hook(socket) do
    LiveView.attach_hook(
      socket,
      :invocation_watcher,
      :handle_info,
      fn
        %Phoenix.Socket.Broadcast{topic: "invocation:" <> _} = msg, socket ->
          {:noreply, new_socket} = handle_invocation_message(msg, socket)
          {:halt, new_socket}

        _other, socket ->
          {:cont, socket}
      end
    )
  end

  # NOTE: We no longer derive display mode at `on_mount` time, as the LiveView
  # will explicitly call `configure_invocation_stream/3` once it knows which
  # display variant it wants.

  defp fetch_network(id, assigns) do
    actor = Map.get(assigns, :current_user)

    case Ash.get(Network, id, actor: actor) do
      {:ok, _} = ok -> ok
      {:error, _} = err -> err
    end
  end

  # ---------------------------------------------------------------------------
  # DOM helpers
  # ---------------------------------------------------------------------------

  defp dom_id(%Invocation{sequence_number: seq}, {:grid, rows, cols}) do
    "slot-#{Integer.mod(seq, rows * cols)}"
  end

  defp dom_id(%Invocation{sequence_number: seq}, {:single, offset, stride}) do
    if rem(seq, stride) == offset, do: "slot-#{offset}"
  end

  # ---------------------------------------------------------------------------
  # Genesis invocation handling
  # ---------------------------------------------------------------------------

  defp update_genesis(socket, %Invocation{sequence_number: 0} = inv) do
    Component.assign(socket, genesis_invocation: inv)
  end

  defp update_genesis(socket, %Invocation{run_number: id}) do
    genesis =
      socket.assigns.genesis_invocation ||
        Ash.get!(Invocation, id, authorize?: false)

    Component.assign(socket, :genesis_invocation, genesis)
  end
end
