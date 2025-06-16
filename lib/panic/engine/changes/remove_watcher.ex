defmodule Panic.Engine.Changes.RemoveWatcher do
  @moduledoc """
  Change module for removing a watcher from an installation's watchers array by index.

  This change takes an index argument and removes the watcher at that position from the current watchers list.
  """
  use Ash.Resource.Change

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def change(changeset, _opts, _context) do
    current_watchers = Ash.Changeset.get_attribute(changeset, :watchers) || []
    index = Ash.Changeset.get_argument(changeset, :index)
    new_watchers = List.delete_at(current_watchers, index)
    Ash.Changeset.change_attribute(changeset, :watchers, new_watchers || [])
  end
end
