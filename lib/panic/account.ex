defmodule Panic.Accounts do
  use Ash.Domain

  resources do
    resource Panic.Accounts.User
    resource Panic.Accounts.Token

    resource Panic.Accounts.ApiToken do
      define :create_api_token, args: [:name, :value], action: :create
      define :get_token, args: [:name], action: :get_by_name
    end
  end
end
