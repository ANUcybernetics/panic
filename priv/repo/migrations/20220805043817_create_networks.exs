defmodule Panic.Repo.Migrations.CreateNetworks do
  use Ecto.Migration

  def change do
    create table(:networks) do
      add :name, :string, null: false
      add :models, {:array, :integer}
      add :loop, :boolean, default: false, null: false
      add :owner_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create index(:networks, [:owner_id])
  end
end
