defmodule Panic.Repo do
  use Ecto.Repo,
    otp_app: :panic,
    adapter: Ecto.Adapters.Postgres

  use PetalFramework.Extensions.Ecto.RepoExt
end
