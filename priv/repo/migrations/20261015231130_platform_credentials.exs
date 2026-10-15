defmodule Panic.Repo.Migrations.PlatformCredentials do
  @moduledoc """
  Replaces the per-user token sets (`api_tokens`, joined to users through
  `user_api_tokens`) with a single encrypted `platform_credentials` row.

  Each key is copied from the first token set (by id) that has it, encrypted
  the way AshCloak stores a string: base64 of `Panic.Vault.encrypt!/1` over
  `:erlang.term_to_binary/1`. The old tables are then dropped, so `down/0`
  can't bring the token sets back.
  """

  use Ecto.Migration

  @keys ~w(replicate_token openai_token gemini_token vestaboard_panic_1_token
           vestaboard_panic_2_token vestaboard_panic_3_token vestaboard_panic_4_token)

  def up do
    create table(:platform_credentials, primary_key: false) do
      add :encrypted_vestaboard_panic_4_token, :binary
      add :encrypted_vestaboard_panic_3_token, :binary
      add :encrypted_vestaboard_panic_2_token, :binary
      add :encrypted_vestaboard_panic_1_token, :binary
      add :encrypted_gemini_token, :binary
      add :encrypted_openai_token, :binary
      add :encrypted_replicate_token, :binary
      add :updated_at, :utc_datetime_usec, null: false
      add :inserted_at, :utc_datetime_usec, null: false
      add :id, :bigserial, null: false, primary_key: true
    end

    flush()

    encrypted = Enum.map(legacy_keys(), &encrypt/1)
    now = DateTime.to_iso8601(DateTime.utc_now())
    columns = Enum.map_join(@keys, ", ", &"encrypted_#{&1}")
    placeholders = Enum.map_join(@keys, ", ", fn _ -> "?" end)

    repo().query!(
      "INSERT INTO platform_credentials (id, #{columns}, inserted_at, updated_at) VALUES (1, #{placeholders}, ?, ?)",
      encrypted ++ [now, now]
    )

    drop_if_exists table(:user_api_tokens)
    drop_if_exists table(:api_tokens)
  end

  def down do
    drop table(:platform_credentials)
  end

  # one value (or nil) per key, in @keys order
  defp legacy_keys do
    %{rows: tables} =
      repo().query!("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'api_tokens'")

    if tables == [] do
      Enum.map(@keys, fn _ -> nil end)
    else
      %{rows: rows} =
        repo().query!("SELECT #{Enum.join(@keys, ", ")} FROM api_tokens ORDER BY id")

      for index <- 0..(length(@keys) - 1) do
        Enum.find_value(rows, &Enum.at(&1, index))
      end
    end
  end

  defp encrypt(nil), do: nil

  defp encrypt(value) do
    # releases start the vault before migrating; mix ecto.migrate doesn't
    if !Process.whereis(Panic.Vault), do: {:ok, _} = Panic.Vault.start_link()
    value |> :erlang.term_to_binary() |> Panic.Vault.encrypt!() |> Base.encode64()
  end
end
