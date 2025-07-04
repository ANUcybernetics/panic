defmodule Panic.Engine.Changes.UpdateWatcher do
  @moduledoc """
  Change module for updating a watcher in an installation's watchers array by index.

  This change takes an index argument and a watcher argument, replacing the watcher at that position.
  """
  use Ash.Resource.Change

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def change(changeset, _opts, _context) do
    current_watchers = Ash.Changeset.get_attribute(changeset, :watchers)
    index = Ash.Changeset.get_argument(changeset, :index)
    watcher = Ash.Changeset.get_argument(changeset, :watcher)

    case {current_watchers, index, watcher} do
      {nil, _, _} ->
        Ash.Changeset.add_error(changeset, field: :watchers, message: "watchers attribute is required")

      {_, nil, _} ->
        Ash.Changeset.add_error(changeset, field: :index, message: "index argument is required")

      {_, _, nil} ->
        Ash.Changeset.add_error(changeset, field: :watcher, message: "watcher argument is required")

      {watchers, index, _} when index < 0 or index >= length(watchers) ->
        Ash.Changeset.add_error(changeset, field: :index, message: "index is out of bounds")

      {watchers, index, watcher} ->
        new_watchers = List.replace_at(watchers, index, watcher)
        Ash.Changeset.change_attribute(changeset, :watchers, new_watchers)
    end
  end
end
