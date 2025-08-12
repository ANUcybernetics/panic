alias Panic.Accounts.User

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

# if there's no cybernetics user, create one
case Ash.get(User, %{email: "socy@anu.edu.au"}) do
  {:error, _} ->
    pass = Application.get_env(:panic, :socy_user_pass)

    user =
      User
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{email: "socy@anu.edu.au", password: pass, password_confirmation: pass}
      )
      |> Ash.create!()
end
