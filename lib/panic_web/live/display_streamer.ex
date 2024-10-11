defmodule PanicWeb.DisplayStreamer do
  @moduledoc ~S"""
  A module for subscribing to and managing a stream of invocations in a LiveView.

  This module provides two main functions:
  - `configure_invocation_stream/3` to set up and configure the `:invocations` stream
  - `handle_invocation_message/2` to handle incoming invocation messages
  """
  alias Panic.Engine.Invocation
  alias Phoenix.LiveView

  def configure_invocation_stream(socket, display) do
    socket
    |> Phoenix.Component.assign(display: display, genesis_invocation: nil)
    |> LiveView.stream_configure(:invocations, dom_id: fn invocation -> dom_id(invocation, display) end)
    |> LiveView.stream(:invocations, [])
  end

  def subscribe_to_invocation_stream(socket, network) do
    if LiveView.connected?(socket) do
      PanicWeb.Endpoint.subscribe("invocation:#{network.id}")
    end

    Phoenix.Component.assign(socket, :network, network)
  end

  def handle_invocation_message(message, socket) do
    display = socket.assigns.display
    invocation = message.payload.data

    socket =
      case {invocation, display} do
        {%Invocation{state: :ready}, _} ->
          socket

        {%Invocation{sequence_number: 0, state: :invoking}, {:grid, _row, _col}} ->
          socket
          |> update_genesis(invocation)
          |> LiveView.stream(:invocations, [invocation], reset: true)

        {_, {:grid, _row, _col}} ->
          socket
          |> update_genesis(invocation)
          |> LiveView.stream_insert(:invocations, invocation)

        {%Invocation{sequence_number: sequence_number}, {:single, offset, stride}}
        when rem(sequence_number, stride) == offset ->
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

  defp dom_id(%Invocation{sequence_number: sequence_number}, {:grid, rows, cols}) do
    slot = Integer.mod(sequence_number, rows * cols)
    "slot-#{slot}"
  end

  defp dom_id(%Invocation{sequence_number: sequence_number}, {:single, offset, stride}) do
    if rem(sequence_number, stride) == offset, do: "slot-0"
  end

  defp update_genesis(socket, %Invocation{sequence_number: 0} = invocation) do
    Phoenix.Component.assign(socket, genesis_invocation: invocation)
  end

  defp update_genesis(socket, %Invocation{run_number: invocation_id}) do
    genesis_invocation = socket.assigns.genesis_invocation || Ash.get!(Invocation, invocation_id, authorize?: false)
    Phoenix.Component.assign(socket, :genesis_invocation, genesis_invocation)
  end

  defmacro __using__(_opts) do
    quote do
      def configure_display_stream(socket, network_id, display) do
        # authorize?: false because this might be used for non-logged in views
        network = Ash.get!(Panic.Engine.Network, network_id, authorize?: false)
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
          case {invocation, display} do
            # can ignore "ready" invocations
            {%Invocation{state: :ready}, _} ->
              socket

            # grid view, new run
            {%Invocation{sequence_number: 0, state: :invoking}, {:grid, _row, _col}} ->
              socket
              |> update_genesis(invocation)
              |> stream(:invocations, [invocation], reset: true)

            # grid view, existing run
            {_, {:grid, _row, _col}} ->
              socket
              |> update_genesis(invocation)
              |> stream_insert(:invocations, invocation)

            # single screen view, "hit"
            {%Invocation{sequence_number: sequence_number}, {:single, offset, stride}}
            when rem(sequence_number, stride) == offset ->
              socket
              |> stream_insert(:invocations, invocation, at: 0, limit: 1)
              |> update_genesis(invocation)

            # screen view, "miss"
            {_, {:single, _, _}} ->
              update_genesis(socket, invocation)

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
      defp dom_id(%Invocation{sequence_number: sequence_number}, {:single, offset, stride}) do
        if rem(sequence_number, stride) == offset, do: "slot-0"
      end

      defp update_genesis(socket, %Invocation{sequence_number: 0} = invocation) do
        assign(socket, genesis_invocation: invocation)
      end

      defp update_genesis(socket, %Invocation{run_number: invocation_id}) do
        # take advantage of the fact that the run_number is the id of the genesis invocation
        genesis_invocation = socket.assigns.genesis_invocation || Ash.get!(Invocation, invocation_id, authorize?: false)
        assign(socket, :genesis_invocation, genesis_invocation)
      end
    end
  end
end
