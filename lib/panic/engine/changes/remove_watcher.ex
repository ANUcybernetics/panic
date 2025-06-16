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
    current_watchers = Ash.Changeset.get_attribute(changeset, :watchers)
    index = Ash.Changeset.get_argument(changeset, :index)

    case {current_watchers, index} do
      {nil, _} ->
        Ash.Changeset.add_error(changeset, field: :watchers, message: "watchers attribute is required")

      {_, nil} ->
        Ash.Changeset.add_error(changeset, field: :index, message: "index argument is required")

      {watchers, index} when index < 0 or index >= length(watchers) ->
        Ash.Changeset.add_error(changeset, field: :index, message: "index is out of bounds")

      {watchers, index} ->
        new_watchers = List.delete_at(watchers, index)
        Ash.Changeset.change_attribute(changeset, :watchers, new_watchers)
    end
  end
end
