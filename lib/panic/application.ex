defmodule Panic.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PanicWeb.Telemetry,
      # before the migrator, which encrypts credentials it migrates
      Panic.Vault,
      Panic.Repo,
      {Ecto.Migrator, repos: Application.fetch_env!(:panic, :ecto_repos), skip: skip_migrations?()},
      {Oban,
       AshOban.config(
         Application.fetch_env!(:panic, :ash_domains),
         Application.fetch_env!(:panic, Oban)
       )},
      {AshAuthentication.Supervisor, otp_app: :panic},
      {DNSCluster, query: Application.get_env(:panic, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Panic.PubSub},
      # Start the Presence supervisor
      PanicWeb.Presence,
      # Start a worker by calling: Panic.Worker.start_link(arg)
      # {Panic.Worker, arg},
      # Start to serve requests, typically the last entry
      PanicWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Panic.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PanicWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations? do
    # Releases migrate on boot, which is the sqlite story: the database lives on
    # the machine's own volume, so there is no separate host for a release
    # command to reach. Outside a release, mix ecto.migrate does the job.
    System.get_env("RELEASE_NAME") == nil
  end
end
