defmodule PanicWeb.NetworkLive.RunnerStatusComponent do
  @moduledoc """
  Shows where a network's current run is up to: its status, a countdown while
  the next invocation waits to start, and the run's stats (the same as an
  installation's heads-up display, cost included).

  The status comes from the network's run fields and the latest invocation the
  LiveView has seen, both kept current by `PanicWeb.WatcherSubscriber`; the
  stats from a `PanicWeb.NetworkLive.RunSummary` the LiveView keeps.
  """
  use Phoenix.Component

  import PanicWeb.PanicComponents, only: [countdown: 1, run_stats: 1]

  alias Panic.Engine.Invocation
  alias Panic.Engine.Network
  alias PanicWeb.NetworkLive.RunSummary

  attr :id, :string, required: true
  attr :network, Network, required: true
  attr :current_invocation, Invocation, default: nil
  attr :summary, RunSummary, default: nil

  def runner_status(assigns) do
    assigns = assign(assigns, :status, status(assigns.network, assigns.current_invocation))

    ~H"""
    <div
      id={@id}
      class="mt-4 flex flex-wrap items-center gap-x-6 gap-y-2 text-sm text-base-content/60 [&_dd]:inline [&_dd]:text-base-content [&_dt]:inline [&_dt]:after:content-['_']"
    >
      <dl class="contents">
        <div>
          <dt>status</dt>
          <dd><span class={["badge", status_class(@status)]}>{format_status(@status)}</span></dd>
        </div>
        <div :if={@status == :waiting} id="countdown-container">
          <dt>next invocation in</dt>
          <dd><.countdown id="countdown" target={@current_invocation.invoke_after} /></dd>
        </div>
      </dl>
      <.run_stats :if={@summary} summary={@summary} show_cost? class="contents" />
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

  defp status_class(:idle), do: "badge-neutral"
  defp status_class(:processing), do: "badge-info"
  defp status_class(:waiting), do: "badge-warning"
  defp status_class(:failed), do: "badge-error"

  defp format_status(:idle), do: "Idle"
  defp format_status(:processing), do: "Processing"
  defp format_status(:waiting), do: "Waiting"
  defp format_status(:failed), do: "Failed"
end
