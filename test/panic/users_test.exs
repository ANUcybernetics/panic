defmodule Panic.UsersTest do
  use Panic.DataCase
  use ExUnitProperties
  # alias Panic.Accounts.User

  describe "ApiToken resource actions" do
    test "can set replicate token" do
      user = Panic.Fixtures.user()
      token_name = :replicate_token
      token_value = "alksdjf;asl"
      user = Panic.Accounts.set_token!(user, token_name, token_value)
      assert user.replicate_token == token_value
    end

    test "set api token (for all valid token names)" do
      user = Panic.Fixtures.user()

      token_names = [
        :replicate_token,
        :openai_token,
        :vestaboard_panic_1_token,
        :vestaboard_panic_2_token,
        :vestaboard_panic_3_token,
        :vestaboard_panic_4_token
      ]

      for name <- token_names do
        value = string(:ascii, min_length: 1) |> pick()

        user = Panic.Accounts.set_token!(user, name, value)
        assert Map.get(user, name) == value
      end
    end

    property "can read (real) tokens from user_with_tokens generator" do
      token_names = [
        :replicate_token,
        :openai_token,
        :vestaboard_panic_1_token,
        :vestaboard_panic_2_token,
        :vestaboard_panic_3_token,
        :vestaboard_panic_4_token
      ]

      check all(
              user <- Panic.Generators.user_with_tokens(),
              token_name <- one_of(token_names)
            ) do
        assert Map.has_key?(user, token_name)
      end
    end

    test "fails with unsupported api token" do
      user = Panic.Fixtures.user()

      assert_raise Ash.Error.Invalid, fn ->
        Panic.Accounts.set_token!(user, :bad_token_name, "bad_value")
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
end
