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
      define :prepare_first, args: [:network, :input], action: :prepare_first
      define :prepare_next, args: [:parent, :input], action: :prepare_next
      define :invoke, args: [], action: :invoke
      define :get_invocation, args: [:id], action: :by_id
    end
  end
end
