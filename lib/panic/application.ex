defmodule Panic.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Panic.Repo,
      # Start the Telemetry supervisor
      PanicWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Panic.PubSub},
      # Start the Endpoint (http/https)
      PanicWeb.Endpoint,
      {Task.Supervisor, name: Panic.BackgroundTask},
      {Oban, oban_config()}
      # Start a worker by calling: Panic.Worker.start_link(arg)
      # {Panic.Worker, arg}
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

  # Conditionally disable queues or plugins here.
  defp oban_config do
    Application.fetch_env!(:panic, Oban)
  end
end
