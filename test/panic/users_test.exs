defmodule Panic.UsersTest do
  use Panic.DataCase
  alias Panic.Accounts.User

  describe "test the User resource" do
    setup do
      {:ok, user: user_fixture()}
    end

    test "creation via Ash changeset works with valid data", %{user: user} do
      assert user.id
      assert user.email
    end

    test "add replicate token to user", %{user: user} do
      user =
        user
        |> Ash.Changeset.for_update(:set_token, %{
          token_name: :replicate,
          token_value: "this_is_a_replicate_token"
        })
        |> Ash.update!()

      assert %{replicate: "this_is_a_replicate_token"} = user.api_tokens

      user =
        user
        |> Ash.Changeset.for_update(:set_token, %{
          token_name: :openai,
          token_value: "this_is_an_openai_token"
        })
        |> Ash.update!()

      assert %{
               replicate: "this_is_a_replicate_token",
               openai: "this_is_an_openai_token"
             } = user.api_tokens
    end

    test "trying to set an unsupported token raises an error" do
      assert_raise Ash.Error.Invalid, fn ->
        user_fixture()
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

  defp user_fixture(attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          email: "jane.citizen@example.com",
          password: "abcd1234",
          password_confirmation: "abcd1234"
        },
        attrs
      )

    User
    |> Ash.Changeset.for_create(:register_with_password, attrs)
    |> Ash.create!()
  end
end
