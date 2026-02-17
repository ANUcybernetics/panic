defmodule Panic.Accounts do
  @moduledoc false
  use Ash.Domain

  resources do
    resource Panic.Accounts.User do
      define :list_users, action: :read
      define :get_user, action: :read, get_by: [:id]
      define :destroy_user, action: :destroy
    end

    resource Panic.Accounts.APIToken do
      define :list_api_tokens, action: :read
      define :get_api_token, action: :read, get_by: [:id]
      define :destroy_api_token, action: :destroy
    end

    resource Panic.Accounts.UserAPIToken do
      define :create_user_api_token, action: :create
    end

    resource Panic.Accounts.Token
  end
end
