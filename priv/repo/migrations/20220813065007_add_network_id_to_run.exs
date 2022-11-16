defmodule Panic.Repo.Migrations.AddNetworkIdToRun do
  use Ecto.Migration

  def change do
    alter table(:runs) do
      add :network_id, references(:networks, on_delete: :delete_all)
    end

    create index(:runs, [:network_id])
  end
end
