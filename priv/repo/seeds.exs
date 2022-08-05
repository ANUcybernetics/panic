# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Panic.Repo.insert!(%Panic.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Panic.Accounts.{User, UserToken, UserTOTP, UserSeeder}
alias Panic.Logs.Log
alias Panic.Orgs.OrgSeeder
alias Panic.Orgs.{Org, Membership, Invitation}

if Mix.env() == :dev do
  Panic.Repo.delete_all(Log)
  Panic.Repo.delete_all(UserTOTP)
  Panic.Repo.delete_all(Invitation)
  Panic.Repo.delete_all(Membership)
  Panic.Repo.delete_all(Org)
  Panic.Repo.delete_all(UserToken)
  Panic.Repo.delete_all(User)

  admin = UserSeeder.admin()

  normal_user =
    UserSeeder.normal_user(%{
      email: "ben@benswift.me",
      name: "Ben Swift",
      password: "password",
      confirmed_at: Timex.now() |> Timex.to_naive_datetime()
    })

  org = OrgSeeder.random_org(admin)
  Panic.Orgs.create_invitation(org, %{email: normal_user.email})

  UserSeeder.random_users(20)
end
