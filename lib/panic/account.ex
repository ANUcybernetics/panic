defmodule Panic.Accounts do
  @moduledoc false
  use Ash.Domain

  resources do
    resource Panic.Accounts.User do
      define :set_token, args: [:token_name, :token_value], action: :set_token
    end
  end
end
