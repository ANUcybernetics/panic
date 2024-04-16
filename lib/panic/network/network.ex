defmodule Panic.Network do
  use Ash.Domain

  resources do
    resource Panic.Network.Loop
  end
end
