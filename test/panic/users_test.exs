defmodule Panic.UsersTest do
  use Panic.DataCase
  use ExUnitProperties

  describe "admin status" do
    test "a user can't make themselves an admin" do
      user = Panic.Fixtures.user()

      assert {:error, %Ash.Error.Forbidden{}} =
               user
               |> Ash.Changeset.for_update(:set_admin, %{admin: true}, actor: user)
               |> Ash.update()
    end

    test "an admin can make another user an admin" do
      admin =
        Panic.Fixtures.user()
        |> Ash.Changeset.for_update(:set_admin, %{admin: true})
        |> Ash.update!(authorize?: false)

      user = Panic.Fixtures.user()

      assert {:ok, %{admin: true}} =
               user
               |> Ash.Changeset.for_update(:set_admin, %{admin: true}, actor: admin)
               |> Ash.update()
    end
  end

  describe "User registration" do
    property "accepts valid registration input" do
      check all(
              email <- Panic.Generators.email(),
              password <- Panic.Generators.password()
            ) do
        user =
          Panic.Accounts.User
          |> Ash.Changeset.for_create(
            :register_with_password,
            %{email: email, password: password, password_confirmation: password}
          )
          |> Ash.create!(authorize?: false)

        assert Ash.CiString.value(user.email) == email
      end
    end
  end
end
