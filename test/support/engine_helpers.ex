defmodule Panic.EngineHelpers do
  @moduledoc """
  Drives runs in tests. Oban runs in `:manual` testing mode, so nothing runs
  until a test drains a queue, in the test process (and its sandbox).
  """

  @doc """
  Runs the earliest scheduled invocation job, whenever it's scheduled for.
  """
  def run_next_invocation do
    Oban.drain_queue(queue: :invocations, with_scheduled: true, with_limit: 1)
  end

  @doc """
  Runs the queued Vestaboard listener jobs.
  """
  def drain_vestaboards, do: Oban.drain_queue(queue: :vestaboards, with_scheduled: true)

  @doc """
  Runs the queued archiver listener jobs.
  """
  def drain_archiver, do: Oban.drain_queue(queue: :archiver, with_scheduled: true)
end
