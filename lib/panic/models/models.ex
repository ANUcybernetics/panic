defmodule Panic.Models do
  use Ash.Domain

  resources do
    resource Panic.Models.Invocation do
      define :invoke, args: [:model, :input, :run_number], action: :invoke
      define :get_invocation, args: [:id], action: :by_id
    end
  end
end
