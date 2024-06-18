defmodule Panic.Engine do
  use Ash.Domain

  resources do
    resource Panic.Engine.Network do
      define :create_network, args: [:name, :description, :models], action: :create
      define :get_network, args: [:id], action: :by_id
      define :set_state, args: [:state], action: :set_state
    end
  end

  resources do
    resource Panic.Engine.Invocation do
      define :create_first, args: [:network_id, :input], action: :create_first
      define :create_next, args: [:parent_id, :input], action: :create_next
      define :get_invocation, args: [:id], action: :by_id
    end
  end
end
