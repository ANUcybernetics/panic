defmodule Panic.Engine do
  @moduledoc false
  use Ash.Domain, extensions: [AshPhoenix, AshJsonApi.Domain]

  alias Panic.Engine.Invocation
  alias Panic.Engine.Network

  json_api do
    routes do
      base_route "/networks", Network do
        index :read
        get :read
        post :create
        patch :update
        delete :destroy
        patch :update_models, route: "/:id/models"
        patch :start_run, route: "/:id/start_run"
        patch :stop_run, route: "/:id/stop_run"
        related :invocations, :read
        related :installations, :read
      end

      base_route "/invocations", Invocation do
        index :read
        get :read
      end

      base_route "/models", Network do
        route :get, "/", :list_models
      end
    end
  end

  resources do
    resource Network do
      define :create_network, args: [:name, :description], action: :create
      define :update_network, action: :update
      define :list_networks, action: :read
      define :get_network, action: :read, get_by: [:id]
      define :destroy_network, action: :destroy
      define :update_models, args: [:models]
      define :stop_run
      define :begin_run, args: [:current_run_number, :run_started_at]
      define :list_running_networks, action: :running
    end

    resource Invocation do
      define :start_run, args: [:network, :input]
      define :set_run_number, args: [:run_number]
      define :update_input, args: [:input]
      define :update_output, args: [:output]
      define :about_to_invoke, args: []
      define :invoke, args: []
      define :mark_as_failed, args: []
      define :get_invocation, action: :read, get_by: [:id]
      define :list_invocations, action: :read

      define :get_invocation_in_run,
        action: :read,
        get_by: [:run_number, :sequence_number],
        not_found_error?: false

      define :current_run_head, args: [:run_number]
      define :run_footprint, args: [:run_number]
    end
  end
end
