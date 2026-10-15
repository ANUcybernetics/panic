defmodule Panic.Engine.Schedule do
  @moduledoc """
  When the next invocation in a run should start.

  Runs slow down as they age, so a long-running network doesn't burn through
  API credits: one second between invocations for the first ten minutes,
  fifteen seconds up to an hour, then ten minutes. A Vestaboard needs about
  eight seconds to finish flipping, so an invocation that one of them displays
  holds the next one back at least that long.
  """

  @vestaboard_hold_ms 8_000
  @initial_prompt_hold_ms @vestaboard_hold_ms + 2_000

  @doc """
  The time the next invocation should start, given when the run started.

      iex> started = ~U[2026-01-01 00:00:00Z]
      iex> Panic.Engine.Schedule.next_invoke_after(started, ~U[2026-01-01 00:05:00Z], false)
      ~U[2026-01-01 00:05:01.000Z]
      iex> Panic.Engine.Schedule.next_invoke_after(started, ~U[2026-01-01 00:05:00Z], true)
      ~U[2026-01-01 00:05:08.000Z]
      iex> Panic.Engine.Schedule.next_invoke_after(started, ~U[2026-01-01 00:30:00Z], true)
      ~U[2026-01-01 00:30:15.000Z]
      iex> Panic.Engine.Schedule.next_invoke_after(started, ~U[2026-01-01 02:00:00Z], false)
      ~U[2026-01-01 02:10:00.000Z]
  """
  def next_invoke_after(run_started_at, now, vestaboard_hold?) do
    age_ms = DateTime.diff(now, run_started_at, :millisecond)
    hold_ms = if vestaboard_hold?, do: @vestaboard_hold_ms, else: 0
    DateTime.add(now, max(backoff_ms(age_ms), hold_ms), :millisecond)
  end

  @doc """
  The time the first invocation of a run should start. When a Vestaboard
  shows the initial prompt, the first invocation waits so the prompt stays
  readable before the output replaces it.

      iex> Panic.Engine.Schedule.first_invoke_after(~U[2026-01-01 00:00:00Z], false)
      ~U[2026-01-01 00:00:00.000Z]
      iex> Panic.Engine.Schedule.first_invoke_after(~U[2026-01-01 00:00:00Z], true)
      ~U[2026-01-01 00:00:10.000Z]
  """
  def first_invoke_after(now, initial_prompt_hold?) do
    hold_ms = if initial_prompt_hold?, do: @initial_prompt_hold_ms, else: 0
    DateTime.add(now, hold_ms, :millisecond)
  end

  defp backoff_ms(age_ms) do
    cond do
      age_ms < to_timeout(minute: 10) -> to_timeout(second: 1)
      age_ms < to_timeout(hour: 1) -> to_timeout(second: 15)
      true -> to_timeout(minute: 10)
    end
  end
end
