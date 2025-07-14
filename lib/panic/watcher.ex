defmodule Panic.Watcher do
  @moduledoc """
  The Watcher domain manages how AI model invocations are observed and displayed.

  This includes installations (collections of display configurations) and their
  associated watchers that define how invocations should be presented to users.
  """

  use Ash.Domain, extensions: [AshPhoenix]

  resources do
    resource Panic.Watcher.Installation do
      define :read, action: :read
      define :create, action: :create

      define :update, action: :update

      define :destroy, action: :destroy

      define :list, action: :read

      define :add_watcher, action: :add_watcher, args: [:watcher]
      define :remove_watcher, action: :remove_watcher, args: [:watcher_name]
      define :update_watcher, action: :update_watcher, args: [:watcher_name, :updated_watcher]
    end
  end
end
