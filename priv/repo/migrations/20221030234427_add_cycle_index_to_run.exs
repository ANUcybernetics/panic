defmodule Panic.Repo.Migrations.AddCycleIndexToRun do
  use Ecto.Migration

  def change do
    alter table(:runs) do
      add :cycle_index, :integer, null: false, default: 0
    end
  end
end
