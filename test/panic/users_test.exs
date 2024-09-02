defmodule Panic.UsersTest do
  use Panic.DataCase
  use ExUnitProperties
  # alias Panic.Accounts.User

  describe "User token management" do
    test "sets replicate token successfully" do
      user = Panic.Fixtures.user()
      token_name = :replicate_token
      token_value = "alksdjf;asl"
      user = Panic.Accounts.set_token!(user, token_name, token_value)
      assert user.replicate_token == token_value
    end

    test "sets all valid API tokens" do
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

    property "generates users with all valid tokens" do
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

    test "raises error for unsupported API token" do
      user = Panic.Fixtures.user()

      assert_raise Ash.Error.Invalid, fn ->
        Panic.Accounts.set_token!(user, :bad_token_name, "bad_value")
      end
    end
  end

  describe "User registration" do
    property "accepts valid registration input" do
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
