defmodule PanicWeb.DisplayStreamer do
  @moduledoc ~S"""
  A module for subscribing to and managing a stream of invocations in a LiveView.

  This module provides two main functions:
  - `configure_invocation_stream/3` to set up and configure the `:invocations` stream
  - `handle_invocation_message/2` to handle incoming invocation messages
  """
  alias Panic.Engine.Invocation
  alias Phoenix.LiveView

  def configure_invocation_stream(socket, network, display) do
    if LiveView.connected?(socket) do
      PanicWeb.Endpoint.subscribe("invocation:#{network.id}")
    end

    # not sure if there is a better way to check if the stream is already configured, but :shrug:
    socket =
      if Map.has_key?(socket.assigns, :streams) && Map.has_key?(socket.assigns.streams, :invocations) do
        socket
      else
        socket
        |> LiveView.stream_configure(:invocations, dom_id: &dom_id(&1, display))
        |> LiveView.stream(:invocations, [])
      end

    Phoenix.Component.assign(socket, network: network, display: display, genesis_invocation: nil)
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
    if rem(sequence_number, stride) == offset, do: "slot-#{offset}"
  end

  defp update_genesis(socket, %Invocation{sequence_number: 0} = invocation) do
    Phoenix.Component.assign(socket, genesis_invocation: invocation)
  end

  defp update_genesis(socket, %Invocation{run_number: invocation_id}) do
    genesis_invocation = socket.assigns.genesis_invocation || Ash.get!(Invocation, invocation_id, authorize?: false)
    Phoenix.Component.assign(socket, :genesis_invocation, genesis_invocation)
  end
end
