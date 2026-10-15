defmodule Panic.Engine.Errors.RunLocked do
  @moduledoc """
  Returned by `Panic.Engine.start_run/3` when the network's current run is
  still within its lockout period. `retry_at` is when a new run can start.
  """
  use Splode.Error, fields: [:retry_at], class: :invalid

  def message(%{retry_at: retry_at}) do
    "a run is already in progress; try again after #{DateTime.to_iso8601(retry_at)}"
  end
end
