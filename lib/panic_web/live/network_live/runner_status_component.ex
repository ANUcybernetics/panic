defmodule PanicWeb.NetworkLive.RunnerStatusComponent do
  @moduledoc """
  Shows where a network's current run is up to: its status, age and sequence
  number, and a countdown while the next invocation waits to start.

  Everything comes from the network's run fields and the latest invocation
  the LiveView has seen, both kept current by `PanicWeb.WatcherSubscriber`.
  """
  use Phoenix.Component

  alias Panic.Engine.Invocation
  alias Panic.Engine.Network

  attr :id, :string, required: true
  attr :network, Network, required: true
  attr :genesis_invocation, Invocation, default: nil
  attr :current_invocation, Invocation, default: nil

  def runner_status(assigns) do
    assigns =
      assign(assigns,
        status: status(assigns.network, assigns.current_invocation),
        sequence_number: sequence_number(assigns.current_invocation, assigns.genesis_invocation)
      )

    ~H"""
    <div id={@id} class="mb-6">
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <div>
            <span class="text-sm font-medium text-gray-500">Status:</span>
            <span class={["ml-2 px-2 py-1 rounded text-sm font-semibold", status_class(@status)]}>
              {format_status(@status)}
            </span>
          </div>

          <div :if={@genesis_invocation}>
            <span class="text-sm font-medium text-gray-500">Run age:</span>
            <span class="ml-2 text-sm">{format_run_age(@genesis_invocation)}</span>
          </div>

          <div :if={@sequence_number}>
            <span class="text-sm font-medium text-gray-500">Sequence:</span>
            <span class="ml-2 text-sm">#{@sequence_number}</span>
          </div>
        </div>

        <div
          :if={@status == :waiting}
          id="countdown-container"
          phx-hook="RunnerCountdown"
          data-target-time={DateTime.to_iso8601(@current_invocation.invoke_after)}
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

  @doc """
  The status of a network's run, given the latest invocation seen.
  """
  def status(%Network{current_run_number: nil}, %Invocation{state: :failed}), do: :failed
  def status(%Network{current_run_number: nil}, _current), do: :idle

  def status(%Network{current_run_number: run}, %Invocation{run_number: run} = current) do
    case current do
      %{state: :ready, invoke_after: %DateTime{}} -> :waiting
      %{state: :failed} -> :failed
      _ -> :processing
    end
  end

  def status(%Network{}, _current), do: :processing

  defp sequence_number(%Invocation{sequence_number: seq}, _genesis), do: seq
  defp sequence_number(nil, %Invocation{sequence_number: seq}), do: seq
  defp sequence_number(nil, nil), do: nil

  defp status_class(:idle), do: "bg-gray-200 text-gray-700"
  defp status_class(:processing), do: "bg-blue-200 text-blue-700"
  defp status_class(:waiting), do: "bg-yellow-200 text-yellow-700"
  defp status_class(:failed), do: "bg-red-200 text-red-700"

  defp format_status(:idle), do: "Idle"
  defp format_status(:processing), do: "Processing"
  defp format_status(:waiting), do: "Waiting"
  defp format_status(:failed), do: "Failed"

  defp format_run_age(%Invocation{inserted_at: inserted_at}) do
    diff_seconds = DateTime.diff(DateTime.utc_now(), inserted_at, :second)

    cond do
      diff_seconds < 60 -> "#{diff_seconds}s"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m #{rem(diff_seconds, 60)}s"
      true -> "#{div(diff_seconds, 3600)}h #{div(rem(diff_seconds, 3600), 60)}m"
    end
  end
end
