defmodule Panic.Engine.Changes.AddWatcher do
  @moduledoc """
  Change module for adding a watcher to an installation's watchers array.

  This change takes a watcher argument and appends it to the current watchers list.
  """
  use Ash.Resource.Change

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def change(changeset, _opts, _context) do
    current_watchers = Ash.Changeset.get_attribute(changeset, :watchers) || []
    watcher = Ash.Changeset.get_argument(changeset, :watcher)
    new_watchers = current_watchers ++ [watcher]
    Ash.Changeset.change_attribute(changeset, :watchers, new_watchers)
  end
end
