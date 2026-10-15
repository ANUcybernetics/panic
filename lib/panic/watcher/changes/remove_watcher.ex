defmodule Panic.Watcher.Changes.RemoveWatcher do
  @moduledoc """
  Removes the watcher named `watcher_name` from an installation's watchers.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    name = Ash.Changeset.get_argument(changeset, :watcher_name)
    watchers = Ash.Changeset.get_attribute(changeset, :watchers)

    cond do
      # a missing argument already has a Required error from the action
      is_nil(name) ->
        changeset

      Enum.any?(watchers, &(&1.name == name)) ->
        Ash.Changeset.change_attribute(
          changeset,
          :watchers,
          Enum.reject(watchers, &(&1.name == name))
        )

      true ->
        Ash.Changeset.add_error(changeset,
          field: :watcher_name,
          message: "watcher with name '#{name}' not found"
        )
    end
  end
end
