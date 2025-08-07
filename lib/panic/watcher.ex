defmodule Panic.Watcher do
  @moduledoc """
  The Watcher domain manages how AI model invocations are observed and displayed.

  This includes installations (collections of display configurations) and their
  associated watchers that define how invocations should be presented to users.
  """

  use Ash.Domain, extensions: [AshPhoenix]

  resources do
    resource Panic.Watcher.Installation do
      define :get_installation, action: :read, get_by: [:id]
      define :list_installations, action: :read
      define :create_installation, action: :create, args: [:network_id]
      define :update_installation, action: :update
      define :destroy_installation, action: :destroy

      define :add_watcher, action: :add_watcher, args: [:watcher]
      define :remove_watcher, action: :remove_watcher, args: [:watcher_name]
      define :update_watcher, action: :update_watcher, args: [:watcher_name, :updated_watcher]
    end
  end
end
