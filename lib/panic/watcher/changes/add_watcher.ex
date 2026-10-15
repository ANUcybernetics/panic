defmodule Panic.Watcher.Changes.AddWatcher do
  @moduledoc """
  Appends the `watcher` argument to an installation's watchers.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    # a missing argument already has a Required error from the action
    case Ash.Changeset.get_argument(changeset, :watcher) do
      nil ->
        changeset

      watcher ->
        watchers = Ash.Changeset.get_attribute(changeset, :watchers)
        Ash.Changeset.change_attribute(changeset, :watchers, watchers ++ [watcher])
    end
  end
end
