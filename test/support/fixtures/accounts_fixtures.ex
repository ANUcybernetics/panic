defmodule Panic.AccountsFixtures do
  @totp_secret Base.decode32!("PTEPUGZ7DUWTBGMW4WLKB6U63MGKKMCA")

  @moduledoc """
  This module defines test helpers for creating
  entities via the `Panic.Accounts` context.
  """
  alias Panic.Repo
  alias Panic.Accounts
  alias Panic.Accounts.User

  def valid_totp_secret, do: @totp_secret
  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "password"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: Faker.Person.En.first_name() <> " " <> Faker.Person.En.last_name(),
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  def confirmed_user_fixture(attrs \\ %{}) do
    user = user_fixture(attrs)

    {:ok, user} =
      User.confirm_changeset(user)
      |> Repo.update()

    user
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Accounts.register_user()

    {:ok, user} = Accounts.update_user_as_admin(user, attrs)

    user
  end

  def admin_fixture(attrs \\ %{}) do
    user = user_fixture(attrs)
    {:ok, user} = Accounts.update_user_as_admin(user, attrs)

    {:ok, user} =
      User.confirm_changeset(user)
      |> Repo.update()

    user
  end

  def user_totp_fixture(user) do
    %Accounts.UserTOTP{}
    |> Ecto.Changeset.change(user_id: user.id, secret: valid_totp_secret())
    |> Accounts.UserTOTP.ensure_backup_codes()
    |> Repo.insert!()
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
