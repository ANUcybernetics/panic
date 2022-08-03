defmodule PetalPro.Repo.Migrations.CreateOrgs do
  use Ecto.Migration

  def change do
    create table(:orgs) do
      add :name, :string, null: false
      add :slug, :citext, null: false

      timestamps()
    end

    create unique_index(:orgs, [:slug])
  end
end
