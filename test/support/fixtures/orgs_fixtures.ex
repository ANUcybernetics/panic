defmodule Panic.OrgsFixtures do
  alias Panic.{
    AccountsFixtures,
    Orgs,
    Orgs.Membership,
    Accounts.User
  }

  def unique_org_name(), do: "org#{System.unique_integer([:positive])}"
  def unique_invitation_email(), do: "invitation#{System.unique_integer([:positive])}@example.com"

  def org_fixture() do
    user = AccountsFixtures.confirmed_user_fixture()
    org_fixture(user, %{})
  end

  def org_fixture(%User{} = user, attrs \\ %{}) do
    name = unique_org_name()
    attrs = Enum.into(attrs, %{name: name})
    {:ok, org} = Orgs.create_org(user, attrs)
    org
  end

  def membership_fixture(org, user, role \\ :member) do
    Panic.Repo.insert!(Membership.insert_changeset(org, user, role))
  end

  def org_member_fixture(org, user_attrs \\ %{}) do
    user = AccountsFixtures.confirmed_user_fixture(user_attrs)
    membership_fixture(org, user)
    user
  end

  def org_admin_fixture(org, user_attrs \\ %{}) do
    user = AccountsFixtures.confirmed_user_fixture(user_attrs)
    membership_fixture(org, user, :admin)
    user
  end

  def invitation_fixture(org, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        email: unique_invitation_email()
      })

    {:ok, invitation} = Orgs.create_invitation(org, attrs)
    invitation
  end
end
