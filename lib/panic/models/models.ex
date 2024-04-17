defmodule Panic.Models do
  use Ash.Domain

  resources do
    resource Panic.Models.Invocation do
      define :invoke_first, args: [:network_id, :input], action: :create_first
      define :get_invocation, args: [:id], action: :by_id
    end
  end
end
