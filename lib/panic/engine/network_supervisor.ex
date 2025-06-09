defmodule Panic.Engine.NetworkSupervisor do
  @moduledoc """
  DynamicSupervisor for managing NetworkRunner GenServers.

  Each network gets its own NetworkRunner GenServer started on demand.
  """

  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
