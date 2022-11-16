defmodule Panic.Repo.Migrations.UseTextNotStringForIo do
  use Ecto.Migration

  def change do
    alter table(:runs) do
      modify :input, :text, null: false
      modify :output, :text
    end
  end
end
