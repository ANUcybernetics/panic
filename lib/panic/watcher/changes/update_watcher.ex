defmodule Panic.Watcher.Changes.UpdateWatcher do
  @moduledoc """
  Replaces the watcher named `watcher_name` with the `updated_watcher` argument.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    name = Ash.Changeset.get_argument(changeset, :watcher_name)
    updated = Ash.Changeset.get_argument(changeset, :updated_watcher)
    watchers = Ash.Changeset.get_attribute(changeset, :watchers)
    index = Enum.find_index(watchers, &(&1.name == name))

    cond do
      # missing arguments already have Required errors from the action
      is_nil(name) or is_nil(updated) ->
        changeset

      index ->
        Ash.Changeset.change_attribute(
          changeset,
          :watchers,
          List.replace_at(watchers, index, updated)
        )

      true ->
        Ash.Changeset.add_error(changeset,
          field: :watcher_name,
          message: "watcher with name '#{name}' not found"
        )
    end
  end
end
