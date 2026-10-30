defmodule Panic.Repo do
  use AshSqlite.Repo, otp_app: :panic

  def write_transactions?, do: true

  # the SQLite bundled with exqlite, which every environment uses
  def min_sqlite_version, do: %Version{major: 3, minor: 54, patch: 1}
end
