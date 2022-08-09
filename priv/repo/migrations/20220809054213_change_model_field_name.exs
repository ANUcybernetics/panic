defmodule Panic.Repo.Migrations.ChangeModelFieldName do
  use Ecto.Migration

  def change do
    rename table(:runs), :model_name, to: :model
  end
end
