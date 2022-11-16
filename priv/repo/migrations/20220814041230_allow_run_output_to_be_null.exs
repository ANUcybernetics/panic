defmodule Panic.Repo.Migrations.AllowRunOutputToBeNull do
  use Ecto.Migration

  def change do
    alter table(:runs) do
      modify :output, :string, null: true, from: :string
    end
  end
end
