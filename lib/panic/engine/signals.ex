defmodule Panic.Engine.Signals do
  @moduledoc """
  The contract between the engine and whatever reacts to a run.

  `Panic.Engine.Invocation` emits these; listeners declare themselves in their
  own `signals_in` sections (see `Panic.Engine.Invocation`,
  `Panic.Engine.Network` and `Panic.Watcher.Installation`), so the engine
  doesn't know about Vestaboards or archiving.
  """
  use Ash.Signals

  signals do
    signal :run_started do
      argument :invocation_id, :integer, allow_nil?: false
      argument :network_id, :integer, allow_nil?: false
      argument :run_number, :integer, allow_nil?: false
      argument :input, :string, allow_nil?: false
    end

    signal :invocation_completed do
      argument :invocation_id, :integer, allow_nil?: false
      argument :network_id, :integer, allow_nil?: false
      argument :run_number, :integer, allow_nil?: false
      argument :sequence_number, :integer, allow_nil?: false
      argument :output, :string, allow_nil?: false
    end

    signal :invocation_failed do
      argument :invocation_id, :integer, allow_nil?: false
      argument :network_id, :integer, allow_nil?: false
      argument :run_number, :integer, allow_nil?: false
      argument :sequence_number, :integer, allow_nil?: false
    end
  end
end
