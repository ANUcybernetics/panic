defmodule Panic.Watcher.Changes.UpdateWatcher do
  @moduledoc """
  Change module for updating a config in an installation's watchers array by name.

  This change takes a watcher_name argument and an updated_watcher argument, replacing the matching config.
  """
  use Ash.Resource.Change

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def change(changeset, _opts, _context) do
    current_watchers = Ash.Changeset.get_attribute(changeset, :watchers)
    watcher_name = Ash.Changeset.get_argument(changeset, :watcher_name)
    updated_watcher = Ash.Changeset.get_argument(changeset, :updated_watcher)

    case {current_watchers, watcher_name, updated_watcher} do
      {nil, _, _} ->
        Ash.Changeset.add_error(changeset, field: :watchers, message: "watchers attribute is required")

      {_, nil, _} ->
        Ash.Changeset.add_error(changeset, field: :watcher_name, message: "watcher_name argument is required")

      {_, _, nil} ->
        Ash.Changeset.add_error(changeset, field: :updated_watcher, message: "updated_watcher argument is required")

      {watchers, name, updated} ->
        case Enum.find_index(watchers, &(&1.name == name)) do
          nil ->
            Ash.Changeset.add_error(changeset, field: :watcher_name, message: "watcher with name '#{name}' not found")

          index ->
            new_watchers = List.replace_at(watchers, index, updated)
            Ash.Changeset.change_attribute(changeset, :watchers, new_watchers)
        end
    end
  end
end
