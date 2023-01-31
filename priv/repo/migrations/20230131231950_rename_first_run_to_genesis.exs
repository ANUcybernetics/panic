defmodule Panic.Repo.Migrations.RenameFirstRunToGenesis do
  use Ecto.Migration

  def change do
    rename table(:predictions), :first_run_id, to: :genesis_id
  end
end
