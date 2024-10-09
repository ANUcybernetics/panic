defmodule Panic.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :panic

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end

    create_user_from_env()
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

  defp create_user_from_env do
    case System.get_env("PANIC_CREATE_USER") do
      nil ->
        :ok

      user_info ->
        case String.split(user_info, ":") do
          [email, password] ->
            Panic.Accounts.User
            |> Ash.Changeset.for_create(:register_with_password, %{
              email: email,
              password: password,
              password_confirmation: password
            })
            |> Ash.create!()

            IO.puts("User created: #{email}")

          _ ->
            IO.puts("Invalid PANIC_CREATE_USER format. Expected 'email:password'")
        end
    end
  end
end
