defmodule Panic.Repo.Migrations.DropObanTables do
  use Ecto.Migration

  def up do
    drop_if_exists table("oban_jobs")
    drop_if_exists table("oban_peers")
    drop_if_exists table("oban_beats")
  end

  def down do
    # Re-creating Oban tables requires running Oban migrations
    # If you need to rollback, you should re-add Oban to your deps
    # and run its migrations again
    raise "Cannot rollback Oban table drops. Please re-add Oban and run its migrations."
  end
end
