defmodule Panic.UsersTest do
  use Panic.DataCase
  use ExUnitProperties
  alias Panic.Accounts.User

  # describe "CRUD actions" do
  #   # now if our action inputs are invalid when we think they should be valid, we will find out here
  #   property "accepts all valid input" do
  #     check all(input <- create_generator()) do
  #       User
  #       |> Ash.Changeset.for_create(:register_with_password, input)
  #       |> Ash.create!()
  #     end
  #   end
  # end

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

  # TODO not working, need to figure out how to generate unique emails...
  # defp create_generator do
  #   gen all(
  #     user <- string(:ascii, min_length: 1),
  #     unique_integer <- repeatedly(fn -> System.unique_integer([:positive, :monotonic]) end),
  #     domain <- string(:ascii, min_length: 1),
  #     password <- binary(min_length: 8)) do
  #       %{email: "#{user}#{unique_integer}@#{domain}", password: password, password_confirmation: password}
  #   end
  # end
end
