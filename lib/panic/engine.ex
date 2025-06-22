defmodule Panic.Engine do
  @moduledoc false
  use Ash.Domain

  resources do
    resource Panic.Engine.Network do
      define :create_network, args: [:name, :description], action: :create
      define :update_models, args: [:models]
      define :stop_run, args: [:network_id]
    end

    resource Panic.Engine.Invocation do
      define :prepare_first, args: [:network, :input]
      define :prepare_next, args: [:previous_invocation]
      define :invoke, args: []
      define :about_to_invoke, args: []
      define :mark_as_failed, args: []
      define :update_input, args: [:input]
      define :update_output, args: [:output]
      define :list_run, args: [:network_id, :run_number]
      define :current_run, args: [:network_id, {:optional, :limit}]
      define :most_recent, args: [:network_id], get?: true
    end

    resource Panic.Engine.Installation
  end
end
