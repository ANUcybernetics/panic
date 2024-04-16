defmodule Panic.Topology do
  use Ash.Domain

  resources do
    resource Panic.Topology.Network
  end
end
