defmodule Panic.Repo.Migrations.AddObanJobsTableAgain do
  use Ecto.Migration

  # Oban has since been removed from the project, so Oban.Migration is no longer
  # available to call here. DropObanTables drops these tables again a few
  # migrations later, so on a fresh database the pair is a no-op; databases that
  # already ran this keep the result they have.
  def up, do: :ok

  def down, do: :ok
end
