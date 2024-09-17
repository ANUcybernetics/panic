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
case Ash.get(Panic.Accounts.User, %{email: "socy@anu.edu.au"}) do
  {:error, _} ->
    pass = Application.get_env(:panic, :socy_user_pass)

    user =
      Panic.Accounts.User
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{email: "socy@anu.edu.au", password: pass, password_confirmation: pass}
      )
      |> Ash.create!()

    # add the tokens from the secrets file
    Application.get_env(:panic, :api_tokens)
    |> Enum.map(fn {name, value} ->
      Panic.Accounts.set_token!(user, name, value, actor: user)
    end)
end
