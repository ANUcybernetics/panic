defmodule Panic.Repo.Migrations.CreatePredictions do
  use Ecto.Migration

  def change do
    create table(:predictions) do
      add :model, :string
      add :input, :text
      add :output, :text
      add :metadata, :map
      add :run_index, :integer
      add :network_id, references(:networks, on_delete: :nothing)
      add :first_run_id, references(:predictions, on_delete: :nothing)

      timestamps()
    end

    create index(:predictions, [:network_id])
    create index(:predictions, [:first_run_id])
  end
end
