defmodule Panic.Repo.Migrations.AddFirstRunIdToRun do
  use Ecto.Migration

  def change do
    ## necessary because we already added & removed this relation, but didn't
    ## delete the fk constraint apparently
    drop constraint(:runs, "runs_first_run_id_fkey")

    alter table(:runs) do
      ## to make it easier to group chains of runs from a given staring point
      add :first_run_id, references(:runs, on_delete: :nothing)
    end
    create index(:runs, [:first_run_id])
  end
end
