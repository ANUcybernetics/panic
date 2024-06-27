defmodule Panic.UsersTest do
  use Panic.DataCase
  use ExUnitProperties
  # alias Panic.Accounts.User

  describe "ApiToken resource actions" do
    test "set api token (for all valid token names)" do
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

        token =
          Panic.Accounts.ApiToken
          |> Ash.Query.for_read(:get_by_name, %{name: name}, actor: user)
          |> Ash.read_one!()

        assert token.user_id == user.id
        assert token.value == value
      end
    end

    test "create token via code interface" do
      name = :openai
      value = string(:ascii, min_length: 1) |> pick()
      user = Panic.Generators.user_fixture()

      Panic.Accounts.create_api_token!(name, value, actor: user)
    end

    test "fails with unsupported api token" do
      user = Panic.Generators.user_fixture()

      name = :unsupported_token
      value = string(:ascii, min_length: 1) |> pick()

      assert_raise Ash.Error.Invalid, fn ->
        Panic.Accounts.ApiToken
        |> Ash.Changeset.for_create(:create, %{name: name, value: value}, actor: user)
        |> Ash.create!()
      end
    end

    test "get token by name" do
      name = :openai
      value = string(:ascii, min_length: 1) |> pick()
      user = Panic.Generators.user_fixture()

      Panic.Accounts.create_api_token!(name, value, actor: user)

      token =
        Panic.Accounts.ApiToken
        |> Ash.Query.for_read(:get_by_name, %{name: name})
        |> Ash.read_one!()

      assert token.name == :openai
      assert token.value == value
    end

    test "get token by name (code interface version)" do
      name = :openai
      value = string(:ascii, min_length: 1) |> pick()
      user = Panic.Generators.user_fixture()

      Panic.Accounts.create_api_token!(name, value, actor: user)

      token = Panic.Accounts.get_token!(name, actor: user)

      assert token.name == :openai
      assert token.value == value
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
    test "list all api token for user" do
      user = Panic.Generators.user_fixture()

      token_name = :replicate
      token_value = string(:ascii, min_length: 1) |> pick()

      Panic.Accounts.ApiToken
      |> Ash.Changeset.for_create(:create, %{name: token_name, value: token_value}, actor: user)
      |> Ash.create!()

      replicate_token =
        Ash.load!(user, :api_tokens, actor: user)
        |> Map.get(:api_tokens)
        |> Enum.find(fn token -> token.name == token_name end)

      assert replicate_token.value == token_value
    end

    test "only list api tokens belonging to user" do
      user1 = Panic.Generators.user_fixture()
      user2 = Panic.Generators.user_fixture()
      value1 = string(:ascii, min_length: 1) |> pick()
      value2 = string(:ascii, min_length: 1) |> pick()

      Panic.Accounts.ApiToken
      |> Ash.Changeset.for_create(:create, %{name: :replicate, value: value1}, actor: user1)
      |> Ash.create!()

      # user2 has an :openai token
      Panic.Accounts.ApiToken
      |> Ash.Changeset.for_create(:create, %{name: :replicate, value: value2}, actor: user2)
      |> Ash.create!()

      # check that user1 can't read user2's tokens
      [token1] =
        Ash.load!(user1, :api_tokens)
        |> Map.get(:api_tokens)

      assert token1.name == :replicate
      assert token1.value == value1

      # check that user2 can't read user1's tokens
      [token2] =
        Ash.load!(user2, :api_tokens)
        |> Map.get(:api_tokens)

      assert token2.name == :replicate
      assert token2.value == value2
    end
  end
end
