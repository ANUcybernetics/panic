defmodule Panic.Engine.Validations.UniqueWatcherNames do
  @moduledoc """
  Validates that all watcher names within an installation are unique.
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_argument_or_attribute(changeset, :watchers) do
      watchers when is_list(watchers) ->
        names = Enum.map(watchers, & &1.name)
        unique_names = Enum.uniq(names)

        if length(names) == length(unique_names) do
          :ok
        else
          duplicate_names =
            names
            |> Enum.frequencies()
            |> Enum.filter(fn {_name, count} -> count > 1 end)
            |> Enum.map(&elem(&1, 0))
            |> Enum.join(", ")

          {:error, field: :watchers, message: "Watcher names must be unique. Duplicates found: #{duplicate_names}"}
        end

      _ ->
        :ok
    end
  end
end