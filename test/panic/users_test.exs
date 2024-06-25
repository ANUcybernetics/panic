defmodule Panic.UsersTest do
  use Panic.DataCase
  use ExUnitProperties
  # alias Panic.Accounts.User

  describe "ApiToken CRUD actions" do
    test "set all api tokens" do
      user = Panic.Generators.user_fixture()

      token_names = [
        :replicate,
        :openai,
        :vestaboard_panic_1,
        :vestaboard_panic_2,
        :vestaboard_panic_3,
        :vestaboard_panic_4
      ]

      for name <- token_names do
        value = string(:ascii, min_length: 1) |> pick()

        Panic.Accounts.ApiToken
        |> Ash.Changeset.for_create(:create, %{name: name, value: value}, actor: user)
        |> Ash.create!()

        token = Ash.get!(Panic.Accounts.ApiToken, name, load: :user)
        assert token.user.id == user.id
        assert token.value == value
      end
    end
  end

  describe "CRUD actions" do
    #   # now if our action inputs are invalid when we think they should be valid, we will find out here
    property "accepts all valid input" do
      check all(
              email <- Panic.Generators.email(),
              password <- Panic.Generators.password()
            ) do
        Panic.Accounts.User
        |> Ash.Changeset.for_create(
          :register_with_password,
          %{email: email, password: password, password_confirmation: password}
        )
        # NOTE: doesn't check that the data is persisted correctly
        |> Ash.create!()
      end
    end
  end

  describe "User resource" do
    property "add api token to user" do
      user = Panic.Generators.user_fixture()

      check all(
              token_name <- member_of([:openai, :replicate]),
              # for some reason this fails if it's a string with leading/trailing whitespace
              token_value <- string(:alphanumeric, min_length: 1)
            ) do
        user =
          user
          |> Ash.Changeset.for_update(:set_token, %{
            token_name: token_name,
            token_value: token_value
          })
          |> Ash.update!()

        assert user.api_tokens[token_name] == token_value
      end
    end

    property "trying to set an unsupported token raises an error" do
      user = Panic.Generators.user_fixture()

      assert_raise Ash.Error.Invalid, fn ->
        user
        |> Ash.Changeset.for_update(:set_token, %{
          token_name: :unsupported,
          token_value: "this_is_an_unsupported_token"
        })
        |> Ash.update!()
      end

      # test "creation with invalid data returns an error changeset" do
      # end

      # test "reading a created user back from the db", %{user: user} do
      # end

      # test "raises an error if there's no user with a given id" do
      # end

      # test "unique constraint on :email is respected", %{user: user} do
      # end

      # test "authentication by policy works", %{user: user} do
      # end
    end
  end
end
