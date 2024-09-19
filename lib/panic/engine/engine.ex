defmodule Panic.Engine do
  @moduledoc false
  use Ash.Domain

  resources do
    resource Panic.Engine.Network do
      define :create_network, args: [:name, :description], action: :create
      define :update_models, args: [:models], action: :update_models
      define :start_run, args: [:first_invocation], action: :start_run
      define :stop_run, args: [:network_id], action: :stop_run
    end

    resource Panic.Engine.Invocation do
      define :prepare_first, args: [:network, :input], action: :prepare_first
      define :prepare_next, args: [:previous_invocation], action: :prepare_next
      define :invoke, args: [], action: :invoke
      define :list_run, args: [:network_id, :run_number], action: :list_run, get?: false

      define :most_recent_invocations,
        args: [:network_id, :limit],
        action: :most_recent,
        get?: false
    end
  end
end
