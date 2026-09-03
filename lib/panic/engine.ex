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
      define :stop_run, args: [:network_id]
    end

    resource Panic.Engine.Invocation do
      define :prepare_first, args: [:network, :input]
      define :prepare_next, args: [:previous_invocation]
      define :invoke, args: []
      define :about_to_invoke, args: []
      define :mark_as_failed, args: []
      define :get_invocation, action: :read, get_by: [:id]
    end
  end
end
