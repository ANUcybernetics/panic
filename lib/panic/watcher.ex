defmodule Panic.Watcher do
  @moduledoc """
  The Watcher domain manages how AI model invocations are observed and displayed.

  This includes installations (collections of display configurations) and their
  associated watchers that define how invocations should be presented to users.
  """

  use Ash.Domain, extensions: [AshPhoenix, AshJsonApi.Domain]

  alias Panic.Watcher.Installation

  forms do
    # the watcher being edited comes from the route, not the form
    form :update_watcher, args: [:watcher_name]
  end

  json_api do
    routes do
      base_route "/installations", Installation do
        index :read
        get :read
        post :create
        patch :update
        delete :destroy
        patch :add_watcher, route: "/:id/add_watcher"
        patch :update_watcher, route: "/:id/update_watcher"
        patch :remove_watcher, route: "/:id/remove_watcher"
      end
    end
  end

  resources do
    resource Installation do
      define :create_installation, action: :create
      define :update_installation, action: :update
      define :get_installation, action: :read, get_by: [:id]
      define :list_installations, action: :read
      define :destroy_installation, action: :destroy

      define :add_watcher, action: :add_watcher, args: [:watcher]
      define :remove_watcher, action: :remove_watcher, args: [:watcher_name]
      define :update_watcher, action: :update_watcher, args: [:watcher_name, :updated_watcher]
    end
  end
end
