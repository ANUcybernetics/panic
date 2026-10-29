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
    <div id={@id} class="mt-4 flex flex-wrap items-center gap-x-6 gap-y-2 text-sm">
      <div>
        <span class="text-base-content/60">Status:</span>
        <span class={["badge ml-1", status_class(@status)]}>{format_status(@status)}</span>
      </div>

      <div :if={@genesis_invocation}>
        <span class="text-base-content/60">Run age:</span>
        <span class="ml-1">{format_run_age(@genesis_invocation)}</span>
      </div>

      <div :if={@sequence_number}>
        <span class="text-base-content/60">Sequence:</span>
        <span class="ml-1">#{@sequence_number}</span>
      </div>

      <div
        :if={@status == :waiting}
        id="countdown-container"
        phx-hook="RunnerCountdown"
        data-target-time={DateTime.to_iso8601(@current_invocation.invoke_after)}
      >
        <span class="text-base-content/60">Next invocation in</span>
        <span id="countdown-display">--</span>
        <span class="text-base-content/60">seconds</span>
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

  defp status_class(:idle), do: "badge-neutral"
  defp status_class(:processing), do: "badge-info"
  defp status_class(:waiting), do: "badge-warning"
  defp status_class(:failed), do: "badge-error"

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
