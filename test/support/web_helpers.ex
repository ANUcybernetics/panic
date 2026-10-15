defmodule PanicWeb.Helpers do
  @moduledoc """
  Helper functions for Phoenix and LiveView tests.
  """
  alias AshAuthentication.Plug.Helpers
  alias Panic.Accounts.User

  def create_and_sign_in_user(%{conn: conn}) do
    password = "abcd1234"
    user = Panic.Fixtures.user(password)

    strategy = AshAuthentication.Info.strategy!(User, :password)

    {:ok, user} =
      AshAuthentication.Strategy.action(strategy, :sign_in, %{
        email: user.email,
        password: password
      })

    %{
      conn:
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Helpers.store_in_session(user),
      user: user
    }
  end

  def create_and_sign_in_admin_user(%{conn: conn}) do
    password = "abcd1234"
    user = Panic.Fixtures.user(password)

    # Update user to be admin
    updated_user =
      user
      |> Ash.Changeset.for_update(:set_admin, %{admin: true})
      |> Ash.update!(authorize?: false)

    strategy = AshAuthentication.Info.strategy!(User, :password)

    {:ok, signed_in_user} =
      AshAuthentication.Strategy.action(strategy, :sign_in, %{
        email: updated_user.email,
        password: password
      })

    %{
      conn:
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Helpers.store_in_session(signed_in_user),
      user: signed_in_user
    }
  end
end
