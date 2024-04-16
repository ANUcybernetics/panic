defmodule Panic.Topology do
  use Ash.Domain

  resources do
    resource Panic.Topology.Network do
      define :create_network, args: [:name, :description, :models], action: :create
      define :get_network, args: [:id], action: :by_id
    end
  end
end
