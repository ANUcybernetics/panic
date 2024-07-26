defmodule Mix.Tasks.AshSqlite.Raze do
  @moduledoc """
  Delete all (ash_sqlite-generated) migrations and resource snapshots

  This is useful for early development when the resources are changing
  a lot, especially in ways that make auto-generated migrations tricky/impossible.

  The general workflow is

  1. use this (`mix ash_sqlite.raze`) to delete all the migrations and resource_snapshots in the app
  2. mix ecto.reset
  3. start again with a new `mix ash_sqlite.generate_migrations`

  Note: `@snapshot_path` and `@migrations_path` are currently hardcoded to their default values. If you
  use different values (via arguments to `ash_sqlite.generate_migrations`) then you'll want to edit the values.
  """

  use Mix.Task

  @snapshot_path "priv/resource_snapshots"
  @migrations_path "priv/repo/migrations"

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("removing snapshot dir #{@snapshot_path}")
    File.rm_rf!(@snapshot_path)

    Mix.shell().info("removing migrations in #{@migrations_path}")

    Path.wildcard(@migrations_path <> "//*.exs")
    |> Enum.filter(&String.match?(&1, ~r|/[0-9]{14}|))
    # leave the initial oban migration, because we probably still want that
    |> Enum.reject(&String.contains?(&1, "add_oban_jobs_table"))
    |> Enum.each(&File.rm!/1)
  end
end
