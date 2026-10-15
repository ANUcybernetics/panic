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
      define :list_running_networks, action: :running
    end

    resource Invocation do
      define :start_run, args: [:network, :input]
      define :invoke, args: []
      define :mark_as_failed, args: []
      define :get_invocation, action: :read, get_by: [:id]
      define :current_run_head, args: [:run_number]
    end
  end
end
