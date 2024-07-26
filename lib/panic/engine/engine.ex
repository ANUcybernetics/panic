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
      define :prepare_next, args: [:previous_invocation], action: :prepare_next
      define :invoke, args: [], action: :invoke
      define :get_invocation, args: [:id], action: :by_id
      define :all_in_run, args: [:network_id, :run_number], action: :all_in_run, get?: false
      define :most_recent_invocation, args: [:network_id], action: :most_recently_updated
    end
  end
end
