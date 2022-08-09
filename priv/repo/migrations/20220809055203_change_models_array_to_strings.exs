defmodule Panic.Repo.Migrations.ChangeModelsArrayToStrings do
  use Ecto.Migration

  def change do
    alter table(:networks) do
      modify :models, {:array, :string}
    end
  end
end
