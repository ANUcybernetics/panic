defmodule Panic.Repo do
  use AshSqlite.Repo, otp_app: :panic

  def write_transactions?, do: true
end
