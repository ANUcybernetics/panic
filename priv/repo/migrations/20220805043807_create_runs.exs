defmodule Panic.Repo.Migrations.CreateRuns do
  use Ecto.Migration

  def change do
    create table(:runs) do
      add :platform, :string, null: false
      add :model_name, :string, null: false
      add :input, :string, null: false
      add :output, :string, null: false
      add :metadata, :map

      timestamps()
    end
  end
end
