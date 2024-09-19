defmodule Panic.Repo.Migrations.AddInvocationState do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_sqlite.generate_migrations`
  """

  use Ecto.Migration

  def up do
    alter table(:invocations) do
      add :state, :text
    end
  end

  def down do
    alter table(:invocations) do
      remove :state
    end
  end
end
