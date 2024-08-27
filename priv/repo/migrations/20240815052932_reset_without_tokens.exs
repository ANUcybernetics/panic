defmodule :"Elixir.Panic.Repo.Migrations.Reset without tokens" do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_sqlite.generate_migrations`
  """

  use Ecto.Migration

  def up do
    create table(:users, primary_key: false) do
      add :hashed_password, :text, null: false
      add :email, :citext, null: false
      add :id, :bigserial, null: false, primary_key: true
    end

    create unique_index(:users, [:email], name: "users_unique_email_index")

    create table(:networks, primary_key: false) do
      add :user_id, references(:users, column: :id, name: "networks_user_id_fkey", type: :bigint),
        null: false

      add :updated_at, :utc_datetime_usec, null: false
      add :inserted_at, :utc_datetime_usec, null: false
      add :slug, :text
      add :state, :text, null: false
      add :models, {:array, :text}, null: false, default: []
      add :description, :text
      add :name, :text, null: false
      add :id, :bigserial, null: false, primary_key: true
    end

    create table(:invocations, primary_key: false) do
      add :network_id,
          references(:networks, column: :id, name: "invocations_network_id_fkey", type: :bigint),
          null: false

      add :updated_at, :utc_datetime_usec, null: false
      add :inserted_at, :utc_datetime_usec, null: false
      add :run_number, :bigint
      add :sequence_number, :bigint, null: false
      add :output, :text
      add :metadata, :map, null: false, default: %{}
      add :model, :text, null: false
      add :input, :text, null: false
      add :id, :bigserial, null: false, primary_key: true
    end

    create table(:api_tokens, primary_key: false) do
      add :user_id,
          references(:users, column: :id, name: "api_tokens_user_id_fkey", type: :bigint),
          null: false

      add :value, :text, null: false
      add :name, :text, null: false
      add :id, :bigserial, null: false, primary_key: true
    end

    create unique_index(:api_tokens, [:name, :user_id], name: "api_tokens_token_index")
  end

  def down do
    drop_if_exists unique_index(:api_tokens, [:name, :user_id], name: "api_tokens_token_index")

    drop constraint(:api_tokens, "api_tokens_user_id_fkey")

    drop table(:api_tokens)

    drop constraint(:invocations, "invocations_network_id_fkey")

    drop table(:invocations)

    drop constraint(:networks, "networks_user_id_fkey")

    drop table(:networks)

    drop_if_exists unique_index(:users, [:email], name: "users_unique_email_index")

    drop table(:users)
  end
end
