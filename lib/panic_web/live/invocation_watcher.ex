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
  defmacro __using__(opts) do
    quote do
      @impl true
      def mount(_params, _session, socket) do
        {:ok, assign(socket, watcher: unquote(opts[:watcher]))}
      end

      def subscribe_to_network(socket, network_id, actor) do
        network = Ash.get!(Panic.Engine.Network, network_id, actor: actor)
        if connected?(socket), do: PanicWeb.Endpoint.subscribe("invocation:#{network.id}")

        invocations =
          network.id
          |> Panic.Engine.current_run!(stream_limit(socket.assigns.watcher), actor: actor)
          |> Enum.map(fn invocation -> clip_id(invocation, socket.assigns.watcher) end)

        socket
        |> assign(:network, network)
        |> stream(:invocations, invocations)
      end

      def handle_info(%Phoenix.Socket.Broadcast{topic: "invocation:" <> _} = message, socket) do
        watcher = socket.assigns.watcher
        invocation = clip_id(message.payload.data, watcher)

        case watcher do
          {:grid, _row, _col} ->
            {:noreply, stream_insert(socket, :invocations, invocation)}

          {:screen, stride, offset} = watcher ->
            if rem(invocation.sequence_number, stride) == offset do
              {:noreply, stream_insert(socket, :invocations, invocation, at: 0, limit: 1)}
            else
              {:noreply, socket}
            end
        end
      end

      defp stream_limit({:grid, rows, cols}), do: rows * cols
      defp stream_limit({:screen, _, _}), do: 1

      # this hack required because "replace item in stream" only works by :id
      defp clip_id(invocation, {:grid, rows, cols}) do
        Map.update!(invocation, :id, fn id -> Integer.mod(invocation.sequence_number, rows * cols) end)
      end

      defp clip_id(invocation, {:screen, _, _}), do: invocation
    end
  end
end
