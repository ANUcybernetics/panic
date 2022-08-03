defmodule Panic.Repo.Migrations.CreateOrgsMembers do
  use Ecto.Migration

  def change do
    create table(:orgs_memberships) do
      add :org_id, references(:orgs, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role, :string, null: false

      timestamps()
    end

    create unique_index(:orgs_memberships, [:org_id, :user_id])
  end
end
