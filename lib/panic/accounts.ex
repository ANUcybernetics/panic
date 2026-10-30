defmodule Panic.Accounts do
  @moduledoc false
  use Ash.Domain, extensions: [AshPhoenix]

  resources do
    resource Panic.Accounts.User do
      define :list_users, action: :read

      define :register_user,
        action: :register_with_password,
        args: [:email, :password, :password_confirmation]

      define :get_user, action: :read, get_by: [:id]
      define :destroy_user, action: :destroy
    end

    resource Panic.Accounts.PlatformCredentials do
      define :get_platform_credentials, action: :read, get?: true
      define :update_platform_credentials, action: :update
    end

    resource Panic.Accounts.Token

    resource Panic.Accounts.ApiKey do
      define :create_api_key, action: :create, args: [:name]
      define :list_api_keys, action: :read
      define :destroy_api_key, action: :destroy
    end
  end
end
