defmodule Panic.UsersTest do
  use Panic.DataCase
  use ExUnitProperties
  # alias Panic.Accounts.User

  describe "CRUD actions" do
    #   # now if our action inputs are invalid when we think they should be valid, we will find out here
    property "accepts all valid input" do
      check all(
              email <- Ash.Generator.sequence(:unique_email, fn i -> "user-#{i}@example.com" end),
              password <- string(:ascii, min_length: 8)
            ) do
        Panic.Accounts.User
        |> Ash.Changeset.for_create(
          :register_with_password,
          %{email: email, password: password, password_confirmation: password}
        )
        |> Ash.create!()
      end
    end
  end

  describe "User resource" do
    property "add replicate token to user" do
      check all(
              user <- Panic.Generators.user(),
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
      check all(user <- Panic.Generators.user()) do
        assert_raise Ash.Error.Invalid, fn ->
          user
          |> Ash.Changeset.for_update(:set_token, %{
            token_name: :unsupported,
            token_value: "this_is_an_unsupported_token"
          })
          |> Ash.update!()
        end
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
