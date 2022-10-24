defmodule Panic.Accounts.UserSeeder do
  @moduledoc """
  Generates dummy users for the development environment.
  """
  alias Panic.Repo
  alias Panic.Accounts
  alias Panic.Accounts.User

  @password "password"

  def normal_user(attrs \\ %{}) do
    {:ok, user} = Accounts.register_user(attrs)
    {:ok, user} = Accounts.update_user_as_admin(user, attrs)
    user
  end

  def admin(attrs \\ %{}) do
    {:ok, user} =
      normal_user(
        Map.merge(
          %{
            name: "John Smith",
            email: "admin@example.com",
            password: @password,
            confirmed_at: Timex.now() |> Timex.to_naive_datetime()
          },
          attrs
        )
      )
      |> Accounts.toggle_admin()

    user
  end

  def random_user(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> random_user_attributes()
      |> Accounts.register_user()

    user
  end

  # Use this for quickly inserting large numbers of users
  # We use insert_all to avoid hashing passwords one by one, which is slow
  def random_users(count) do
    now =
      Timex.now()
      |> Timex.to_naive_datetime()
      |> NaiveDateTime.truncate(:second)

    # This is for the password "password"
    password_hashed = "$2b$12$RCMCDT1LBBp1q7yGGqwkhuw9OgEFXOJEViSkXtC9VfRmivUh.Gk4a"

    users_data =
      Enum.map(1..count, fn _ ->
        random_user_attributes()
        |> Map.drop([:password])
        |> Map.merge(%{
          inserted_at: now,
          updated_at: now,
          confirmed_at: Enum.random([now, now, now, nil]),
          hashed_password: password_hashed
        })
      end)

    Repo.insert_all(User, users_data)
  end

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"

  def random_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: Faker.Person.En.first_name() <> " " <> Faker.Person.En.last_name(),
      email: unique_user_email(),
      password: "password"
    })
  end
end
