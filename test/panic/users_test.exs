defmodule Panic.NetworkTest do
  use Panic.DataCase
  alias Panic.Accounts.User

  describe "test the User resource" do
    setup do
      {:ok, user: user_fixture()}
    end

    test "creation via Ash changeset works with valid data", %{user: user} do
      assert %{valid?: true} = User.create_user(%{email: "test@example.com", password: "secret"})
    end

    test "creation with invalid data returns an error changeset" do
      assert %{valid?: false} = User.create_user(%{})
    end

    test "reading a created user back from the db", %{user: user} do
      found_user = User.get_user!(user.id)
      assert found_user.email == user.email
    end

    test "raises an error if there's no user with a given id" do
      assert_raise Ecto.NoResultsError, fn -> User.get_user!(12345) end
    end

    test "unique constraint on :email is respected", %{user: user} do
      assert {:error, changeset} = User.create_user(%{email: user.email, password: "secret"})
      assert changeset.errors[:email] != nil
    end

    test "authentication by policy works", %{user: user} do
      assert {:ok, _} = User.authenticate_user(user.email, "secret")
      assert {:error, _} = User.authenticate_user(user.email, "wrongpassword")
    end
  end

  defp user_fixture(attrs \\ %{}) do
    {:ok, user} = User.create_user(Map.merge(%{email: "user@example.com", password: "secret"}, attrs))
    user
  end
end
