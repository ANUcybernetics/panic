defmodule PanicWeb.InvocationWatcher do
  @moduledoc ~S"""
  A behaviour module for subscribing to and managing a stream of invocations in a LiveView.

  `use`ing this module adds

  - a `mount/3` handler which configures the `:invocations` stream (accessible through `@stream.invocations` in your controller/template)
  - a `subscribe_to_network/3` function which initialises the `:invocations stream with values and subscribes to the relevant topic to listen for all invocation-related events
  - `handle_info/2` callbacks to keep your `:invocations` stream up-to-date as new invocations are created & completed
  - a `:watcher` assign, which is a 3-tuple that's either
    - `{:grid, row, col}` for a row x col "grid" (although rendering the invocations into a grid is up to you)
    - `{:screen, stride, offset}` for a single "screen", so that invocations stream is always length 1
  """
  alias Panic.Engine.Invocation

  defmacro __using__(opts) do
    quote do
      @impl true
      def mount(_params, _session, socket) do
        watcher = unquote(opts[:watcher])

        # this config can only happen once, so needs to be in mount/3
        socket =
          socket
          |> assign(watcher: watcher)
          |> stream_configure(:invocations, dom_id: fn invocation -> dom_id(invocation, watcher) end)

        {:ok, socket}
      end

      def subscribe_to_network(socket, network_id, actor) do
        network = Ash.get!(Panic.Engine.Network, network_id, actor: actor)
        if connected?(socket), do: PanicWeb.Endpoint.subscribe("invocation:#{network.id}")

        socket
        |> assign(:network, network)
        |> stream(:invocations, [])
      end

      def handle_info(%Phoenix.Socket.Broadcast{topic: "invocation:" <> _} = message, socket) do
        watcher = socket.assigns.watcher
        invocation = message.payload.data

        socket =
          case {invocation.sequence_number, watcher} do
            # grid view, new run
            {0, {:grid, _row, _col}} ->
              stream(socket, :invocations, [invocation], reset: true)

            # grid view, existing run
            {_, {:grid, _row, _col}} ->
              stream_insert(socket, :invocations, invocation)

            # screen view, "hit"
            {sequence_number, {:screen, stride, offset}} when rem(sequence_number, stride) == offset ->
              stream_insert(socket, :invocations, invocation, at: 0, limit: 1)

            # screen view, "miss"
            {_, {:screen, _}} ->
              socket
          end

        {:noreply, socket}
      end

      defp stream_limit({:grid, rows, cols}), do: rows * cols
      defp stream_limit({:screen, _, _}), do: 1

      defp dom_id(%Invocation{sequence_number: sequence_number}, {:grid, rows, cols}) do
        slot = Integer.mod(sequence_number, rows * cols)
        "slot-#{slot}"
      end

      # for screen, return slot-0 if this one "matches", and nil otherwise
      defp dom_id(%Invocation{sequence_number: sequence_number}, {:screen, stride, offset}) do
        if rem(sequence_number, stride) == offset, do: "slot-0"
      end
    end
  end
end
