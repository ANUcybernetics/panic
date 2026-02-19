defmodule PanicWeb.NetworkLive.RunnerStatusComponent do
  @moduledoc """
  LiveComponent that displays the current status of a NetworkRunner.

  Shows:
  - Current runner status (idle, processing, waiting, failed)
  - Run age (time since genesis invocation)
  - Current sequence number
  - Countdown timer when waiting for next invocation
  """
  use PanicWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="mb-6">
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <div>
            <span class="text-sm font-medium text-gray-500">Status:</span>
            <span class={["ml-2 px-2 py-1 rounded text-sm font-semibold", status_class(@status)]}>
              {@status |> format_status()}
            </span>
          </div>

          <div :if={@genesis_invocation}>
            <span class="text-sm font-medium text-gray-500">Run age:</span>
            <span class="ml-2 text-sm">{format_run_age(@genesis_invocation)}</span>
          </div>

          <div :if={@current_invocation || @genesis_invocation}>
            <span class="text-sm font-medium text-gray-500">Sequence:</span>
            <span class="ml-2 text-sm">
              #{get_sequence_number(@current_invocation, @genesis_invocation)}
            </span>
          </div>
        </div>

        <div
          :if={@status == :waiting && @next_invocation_time}
          id="countdown-container"
          phx-hook="RunnerCountdown"
          data-target-time={DateTime.to_iso8601(@next_invocation_time)}
          class="text-sm font-medium"
        >
          <span class="text-gray-500">Next invocation in </span>
          <span id="countdown-display" class="font-mono">--</span>
          <span class="text-gray-500"> seconds</span>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> derive_status()
      |> fetch_runner_timing()

    {:ok, socket}
  end

  defp derive_status(socket) do
    genesis = socket.assigns[:genesis_invocation]
    current = socket.assigns[:current_invocation]

    status =
      cond do
        is_nil(genesis) ->
          :idle

        current && current.state == :failed ->
          :failed

        current && current.state == :invoking ->
          :processing

        current && current.state == :ready ->
          :processing

        genesis ->
          :waiting

        true ->
          :idle
      end

    assign(socket, :status, status)
  end

  defp fetch_runner_timing(socket) do
    # Only fetch timing info from NetworkRunner for countdown
    case Panic.Engine.NetworkRunner.get_runner_state(socket.assigns.network_id) do
      {:ok, state} ->
        assign(socket, :next_invocation_time, state.next_invocation_time)

      {:error, :not_running} ->
        assign(socket, :next_invocation_time, nil)
    end
  end

  defp status_class(:idle), do: "bg-gray-200 text-gray-700"
  defp status_class(:processing), do: "bg-blue-200 text-blue-700"
  defp status_class(:waiting), do: "bg-yellow-200 text-yellow-700"
  defp status_class(:failed), do: "bg-red-200 text-red-700"
  defp status_class(_), do: "bg-gray-200 text-gray-700"

  defp format_status(:idle), do: "Idle"
  defp format_status(:processing), do: "Processing"
  defp format_status(:waiting), do: "Waiting"
  defp format_status(:failed), do: "Failed"
  defp format_status(_), do: "Unknown"

  defp get_sequence_number(current, genesis) do
    cond do
      current -> Map.get(current, :sequence_number, 0)
      genesis -> Map.get(genesis, :sequence_number, 0)
      true -> 0
    end
  end

  defp format_run_age(nil), do: "N/A"

  defp format_run_age(genesis_invocation) do
    now = DateTime.utc_now()
    inserted_at = Map.get(genesis_invocation, :inserted_at)

    # Handle case where inserted_at might not be present
    if inserted_at do
      diff_seconds = DateTime.diff(now, inserted_at, :second)

      cond do
        diff_seconds < 60 ->
          "#{diff_seconds}s"

        diff_seconds < 3600 ->
          minutes = div(diff_seconds, 60)
          seconds = rem(diff_seconds, 60)
          "#{minutes}m #{seconds}s"

        true ->
          hours = div(diff_seconds, 3600)
          minutes = div(rem(diff_seconds, 3600), 60)
          "#{hours}h #{minutes}m"
      end
    else
      "N/A"
    end
  end
end
