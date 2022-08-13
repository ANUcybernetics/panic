defmodule Panic.Repo.Migrations.RenameFirstRunToParent do
  use Ecto.Migration

  def change do
    rename table(:runs), :first_run_id, to: :parent_id
  end
end
