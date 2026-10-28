defmodule Panic.Engine.Schedule do
  @moduledoc """
  When the next invocation in a run should start, and when an invocation's
  output may be shown.

  Runs slow down as they age, so a long-running network doesn't burn through
  API credits: one second between invocations for the first ten minutes,
  fifteen seconds up to an hour, then ten minutes.

  A Vestaboard takes several seconds to finish flipping, so the invocation
  after one it displays (or after the initial prompt) starts on schedule but
  holds its output back until `hold_until`, the installation's
  `vestaboard_hold_seconds` after the board was sent its text. The model call
  overlaps with the flipping instead of waiting for it.
  """

  @doc """
  The time the next invocation should start, given when the run started.

      iex> started = ~U[2026-01-01 00:00:00Z]
      iex> Panic.Engine.Schedule.next_invoke_after(started, ~U[2026-01-01 00:05:00Z])
      ~U[2026-01-01 00:05:01.000Z]
      iex> Panic.Engine.Schedule.next_invoke_after(started, ~U[2026-01-01 00:30:00Z])
      ~U[2026-01-01 00:30:15.000Z]
      iex> Panic.Engine.Schedule.next_invoke_after(started, ~U[2026-01-01 02:00:00Z])
      ~U[2026-01-01 02:10:00.000Z]
  """
  def next_invoke_after(run_started_at, now) do
    age_ms = DateTime.diff(now, run_started_at, :millisecond)
    DateTime.add(now, backoff_ms(age_ms), :millisecond)
  end

  @doc """
  The earliest time an invocation's output may be shown, given the Vestaboard
  hold in seconds (nil when no Vestaboard was just sent text).

      iex> Panic.Engine.Schedule.hold_until(~U[2026-01-01 00:00:00Z], 10)
      ~U[2026-01-01 00:00:10Z]
      iex> Panic.Engine.Schedule.hold_until(~U[2026-01-01 00:00:00Z], nil)
      nil
  """
  def hold_until(_now, nil), do: nil
  def hold_until(now, hold_seconds), do: DateTime.shift(now, second: hold_seconds)

  @doc """
  How long to wait from `now` until `hold_until`, in milliseconds.

      iex> Panic.Engine.Schedule.remaining_hold_ms(~U[2026-01-01 00:00:10Z], ~U[2026-01-01 00:00:03Z])
      7000
      iex> Panic.Engine.Schedule.remaining_hold_ms(~U[2026-01-01 00:00:10Z], ~U[2026-01-01 00:00:12Z])
      0
      iex> Panic.Engine.Schedule.remaining_hold_ms(nil, ~U[2026-01-01 00:00:12Z])
      0
  """
  def remaining_hold_ms(nil, _now), do: 0
  def remaining_hold_ms(hold_until, now), do: max(DateTime.diff(hold_until, now, :millisecond), 0)

  defp backoff_ms(age_ms) do
    cond do
      age_ms < to_timeout(minute: 10) -> to_timeout(second: 1)
      age_ms < to_timeout(hour: 1) -> to_timeout(second: 15)
      true -> to_timeout(minute: 10)
    end
  end
end
