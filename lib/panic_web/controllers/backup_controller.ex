defmodule PanicWeb.BackupController do
  @moduledoc """
  Controller for database backups. Restricted to admin users only.
  """
  use PanicWeb, :controller
  require Logger

  def download(conn, _params) do
    with :ok <- authorize_admin(conn),
         {:ok, backup_path} <- create_backup(),
         {:ok, data} <- File.read(backup_path) do
      # Clean up the temporary backup file
      File.rm(backup_path)

      # Send the backup as a download
      timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
      filename = "panic_backup_#{timestamp}.db"

      conn
      |> put_resp_content_type("application/octet-stream")
      |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
      |> send_resp(200, data)
    else
      {:error, :unauthorized} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Forbidden"})

      {:error, reason} ->
        Logger.error("Backup failed: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Backup failed"})
    end
  end

  defp authorize_admin(conn) do
    # Get current user from conn assigns (set by authentication plug)
    case conn.assigns[:current_user] do
      nil ->
        {:error, :unauthorized}

      user ->
        # Check if user has admin privileges
        if user.admin == true do
          :ok
        else
          Logger.warning("Unauthorized backup attempt by non-admin user: #{user.email}")
          {:error, :unauthorized}
        end
    end
  end

  defp create_backup do
    # Generate a temporary file path for the backup
    temp_dir = System.tmp_dir!()
    backup_filename = "backup_#{System.unique_integer([:positive])}.db"
    backup_path = Path.join(temp_dir, backup_filename)

    # Get the database configuration
    repo_config = Panic.Repo.config()
    database_path = Keyword.get(repo_config, :database)

    if database_path do
      # Use VACUUM INTO to create a consistent backup
      # This works even while the database is being written to
      query = "VACUUM INTO '#{backup_path}'"

      case Ecto.Adapters.SQL.query(Panic.Repo, query) do
        {:ok, _result} ->
          Logger.info("Database backup created successfully at #{backup_path}")
          {:ok, backup_path}

        {:error, error} ->
          Logger.error("Failed to create backup: #{inspect(error)}")
          {:error, error}
      end
    else
      {:error, :no_database_path}
    end
  end
end