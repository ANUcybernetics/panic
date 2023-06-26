defmodule Panic.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      PanicWeb.Telemetry,
      # Start the Ecto repository
      Panic.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Panic.PubSub},
      # Start Finch
      {Finch, name: Panic.Finch},
      # Start the Endpoint (http/https)
      PanicWeb.Endpoint,
      # Start a worker by calling: Panic.Worker.start_link(arg)
      # {Panic.Worker, arg}
      {Task.Supervisor, name: Panic.Runs.TaskSupervisor}
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
end
