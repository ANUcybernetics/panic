defmodule PetalPro.Repo do
  use Ecto.Repo,
    otp_app: :petal_pro,
    adapter: Ecto.Adapters.Postgres

  use PetalFramework.Extensions.Ecto.RepoExt
end
