defmodule Panic.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :panic

  # gross! gross! gross! but deadlines.
  alias Panic.Accounts
  alias Panic.Accounts.UserSeeder

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end

    maybe_create_user()
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end

  def maybe_create_user do
    unless Accounts.get_user_by_email("socy@anu.edu.au") do
      # this is stolen from seeds.exs, but that doesn't run in prod, so again,
      # it'll do for the exhibition
      normal_user =
        UserSeeder.normal_user(%{
              email: "socy@anu.edu.au",
              name: "Panic Viewer",
              password: "cybernetics",
              confirmed_at: Timex.now() |> Timex.to_naive_datetime()})

      org = Panic.Orgs.list_orgs() |> List.first()
      Panic.Orgs.create_invitation(org, %{email: normal_user.email})
    end
  end
end
