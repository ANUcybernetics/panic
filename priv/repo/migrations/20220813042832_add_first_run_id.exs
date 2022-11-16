defmodule Panic.Repo.Migrations.AddFirstRunId do
  use Ecto.Migration

  def change do
    alter table(:runs) do
      add :first_run_id, references(:runs, on_delete: :nothing)
    end
  end
end
