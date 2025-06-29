defmodule Panic.Repo.Migrations.AddGeminiTokenToUsers do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_sqlite.generate_migrations`
  """

  use Ecto.Migration

  def up do
    alter table(:users) do
      add :gemini_token, :text
    end
  end

  def down do
    alter table(:users) do
      remove :gemini_token
    end
  end
end
