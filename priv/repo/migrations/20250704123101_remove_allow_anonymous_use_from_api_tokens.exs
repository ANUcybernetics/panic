defmodule Panic.Repo.Migrations.RemoveAllowAnonymousUseFromApiTokens do
  use Ecto.Migration

  def up do
    alter table(:api_tokens) do
      remove :allow_anonymous_use
    end
  end

  def down do
    alter table(:api_tokens) do
      add :allow_anonymous_use, :boolean, default: false, null: false
    end
  end
end
