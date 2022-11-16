defmodule Panic.Repo.Migrations.RemovePlatformField do
  use Ecto.Migration

  def change do
    alter table(:runs) do
      remove :platform
    end
  end
end
