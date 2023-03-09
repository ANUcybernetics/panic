defmodule Panic.Repo.Migrations.AddVestaboardsArrayToNetwork do
  use Ecto.Migration

  def change do
    alter table(:networks) do
      add :vestaboards, {:array, :string}
    end
  end
end
