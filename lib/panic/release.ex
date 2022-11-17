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
    email = "socy@anu.edu.au"

    unless Accounts.get_user_by_email(email) do
      # this is stolen from seeds.exs, but that doesn't run in prod, so again,
      # it'll do for the exhibition
      UserSeeder.normal_user(%{
        email: email,
        name: "Panic Viewer",
        password: "cybernetics"
      })
      |> Accounts.confirm_user!()
    end
  end
end
