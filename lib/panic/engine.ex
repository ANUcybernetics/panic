defmodule Panic.Engine do
  @moduledoc false
  use Ash.Domain

  resources do
    resource Panic.Engine.Network do
      define :create_network, args: [:name, :description], action: :create
      define :list_networks, action: :read
      define :get_network, action: :read, get_by: [:id]
      define :destroy_network, action: :destroy
      define :update_models, args: [:models]
      define :stop_run
      define :list_running_networks, action: :running
    end

    resource Panic.Engine.Invocation do
      define :start_run, args: [:network, :input]
      define :invoke, args: []
      define :mark_as_failed, args: []
      define :get_invocation, action: :read, get_by: [:id]
      define :current_run_head, args: [:run_number]
    end
  end
end
