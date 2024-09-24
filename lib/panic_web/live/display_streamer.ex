defmodule PanicWeb.DisplayStreamer do
  @moduledoc ~S"""
  A behaviour module for subscribing to and managing a stream of invocations in a LiveView.

  `use` this module in a LiveView to add:
  - a `mount/3` handler which
  - `handle_info/2` callbacks to keep your `:invocations` stream up-to-date as
    new invocations are created & completed
  - a `configure_display_stream/3` function which sets up and configures the
    `:invocations` stream (accessible through `@stream.invocations` in your
    controller/template) and subscribes to the relevant topic to listen for all
    invocation-related events

  If you don't use `configure_display_stream/3` it's up to you to to ensure that you
  set the following assigns:
  - `:network` (a `%Panic.Engine.Network`)
  - a `:display` assign, which is a 3-tuple that's either
    - `{:grid, row, col}` for a row x col "grid" (although rendering the invocations into a grid is up to you)
    - `{:single, stride, offset}` for a single "screen", so that invocations stream is always length 1
    - `:genesis_invocation` is the most-recent completed invocation with `:sequence_number == 0` (or `nil`)
  """
  alias Panic.Engine.Invocation

  defmacro __using__(_opts) do
    quote do
      def configure_display_stream(socket, network_id, display) do
        network = Ash.get!(Panic.Engine.Network, network_id, actor: socket.assigns.current_user)
        if connected?(socket), do: PanicWeb.Endpoint.subscribe("invocation:#{network.id}")

        socket
        |> assign(network: network, display: display, genesis_invocation: nil)
        # TODO this shouldn't run more than once... but needs to be in handle_params
        |> stream_configure(:invocations, dom_id: fn invocation -> dom_id(invocation, display) end)
        |> stream(:invocations, [])
      end

      @impl true
      def handle_info(%Phoenix.Socket.Broadcast{topic: "invocation:" <> _} = message, socket) do
        display = socket.assigns.display
        invocation = message.payload.data

        socket =
          case {invocation.sequence_number, display} do
            # grid view, new run
            {0, {:grid, _row, _col}} ->
              socket
              |> assign(genesis_invocation: invocation)
              |> stream(:invocations, [invocation], reset: true)

            # grid view, existing run
            {_, {:grid, _row, _col}} ->
              stream_insert(socket, :invocations, invocation)

            # single screen view, "hit"
            {sequence_number, {:single, stride, offset}} when rem(sequence_number, stride) == offset ->
              stream_insert(socket, :invocations, invocation, at: 0, limit: 1)

            # screen view, "miss"
            {_, {:single, _, _}} ->
              socket

            # otherwise ignore
            _ ->
              socket
          end

        {:noreply, socket}
      end

      defp dom_id(%Invocation{sequence_number: sequence_number}, {:grid, rows, cols}) do
        slot = Integer.mod(sequence_number, rows * cols)
        "slot-#{slot}"
      end

      # for screen, return slot-0 if this one "matches", and nil otherwise
      defp dom_id(%Invocation{sequence_number: sequence_number}, {:single, stride, offset}) do
        if rem(sequence_number, stride) == offset, do: "slot-0"
      end
    end
  end
end
