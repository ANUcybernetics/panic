defmodule Panic.Accounts do
  use Ash.Domain

  resources do
    resource Panic.Accounts.User
    resource Panic.Accounts.Token
  end
end
