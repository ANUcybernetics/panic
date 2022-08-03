defmodule PetalPro.Repo.Migrations.AddFieldsToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :name, :string
      add :avatar, :string
      add :last_signed_in_ip, :string
      add :last_signed_in_datetime, :utc_datetime
      add :is_subscribed_to_marketing_notifications, :boolean, null: false, default: true
      add :is_admin, :boolean, null: false, default: false
      add :is_suspended, :boolean, null: false, default: false
      add :is_deleted, :boolean, null: false, default: false
      add :is_onboarded, :boolean, null: false, default: false
    end

    create index(:users, [:is_deleted, :is_suspended])
  end
end
