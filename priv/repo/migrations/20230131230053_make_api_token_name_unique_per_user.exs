defmodule Panic.Repo.Migrations.MakeApiTokenNameUniquePerUser do
  use Ecto.Migration

  def change do
    create unique_index(:api_tokens, [:user_id, :name])
  end
end
