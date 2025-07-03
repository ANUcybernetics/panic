defmodule Panic.Accounts do
  @moduledoc false
  use Ash.Domain

  resources do
    resource Panic.Accounts.User

    resource Panic.Accounts.APIToken
    resource Panic.Accounts.UserAPIToken
  end
end
