defmodule Panic.NetworkTest do
  use Panic.DataCase
  alias Panic.Accounts.User

  describe "test the User resource" do
    setup do
      {:ok, user: user_fixture()}
    end

    test "creation via Ash changeset works with valid data", %{user: user} do
      # code goes here
    end

    test "creation with invalid data returns an error changeset" do
      # code goes here
    end

    test "reading a created user back from the db", %{user: user} do
      # code goes here
    end

    test "raises an error if there's no user with a given id" do
      # code goes here
    end

    test "unique constraint on :email is respected", %{user: user} do
      # code goes here
    end

    test "authentication by policy works", %{user: user} do
      # code goes here
    end
  end

  defp user_fixture(attrs \\ %{}) do
    @doc "create a user from `attrs` using `Ash.Changeset.for_create/2`"
    # code goes here
  end
end
