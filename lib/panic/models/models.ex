defmodule Panic.Models do
  use Ash.Domain

  resources do
    resource Panic.Models.Invocation
  end
end
