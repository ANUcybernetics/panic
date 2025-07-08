defmodule Panic.Watcher.Changes.RemoveWatcher do
  @moduledoc """
  Change module for removing a config from an installation's watchers array by name.

  This change takes a watcher_name argument and removes the matching config from the current watchers list.
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

    case {current_watchers, watcher_name} do
      {nil, _} ->
        Ash.Changeset.add_error(changeset, field: :watchers, message: "watchers attribute is required")

      {_, nil} ->
        Ash.Changeset.add_error(changeset, field: :watcher_name, message: "watcher_name argument is required")

      {watchers, name} ->
        case Enum.find_index(watchers, &(&1.name == name)) do
          nil ->
            Ash.Changeset.add_error(changeset, field: :watcher_name, message: "watcher with name '#{name}' not found")

          _index ->
            new_watchers = Enum.reject(watchers, &(&1.name == name))
            Ash.Changeset.change_attribute(changeset, :watchers, new_watchers)
        end
    end
  end
end