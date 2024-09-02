ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Panic.Repo, :manual)

defmodule Panic.Generators do
  @moduledoc """
  StreamData generators for Panic resources.
  """
  use ExUnitProperties

  def ascii_sentence do
    string(:ascii, min_length: 1)
    |> map(&String.trim/1)
    |> filter(&(String.length(&1) > 0))
  end

  def model(filters \\ []) do
    filters
    |> Panic.Models.list()
    |> one_of()
  end

  def password do
    string(:utf8, min_length: 8)
    |> filter(fn s -> not Regex.match?(~r/^[[:space:]]*$/, s) end)
    |> filter(fn s -> String.length(s) >= 8 end)
  end

  def email do
    repeatedly(fn -> System.unique_integer([:positive]) end)
    |> map(fn i -> "user-#{i}@example.com" end)
  end

  def user(password_generator \\ password()) do
    gen all(email <- email(), password <- password_generator) do
      Panic.Accounts.User
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{email: email, password: password, password_confirmation: password}
      )
      |> Ash.create!()
    end
  end

  def set_all_tokens(user) do
    Application.get_env(:panic, :api_tokens)
    |> Enum.map(fn {name, value} ->
      Panic.Accounts.set_token!(user, name, value, actor: user)
    end)
    |> List.last()
  end

  def user_with_tokens do
    gen all(user <- user()) do
      user = set_all_tokens(user)
      Ash.get!(Panic.Accounts.User, user.id, actor: user)
    end
  end

  def network(user) do
    gen all(input <- Ash.Generator.action_input(Panic.Engine.Network, :create)) do
      Panic.Engine.Network
      |> Ash.Changeset.for_create(:create, input, actor: user)
      |> Ash.create!()
    end
  end

  def network_with_models(user) do
    gen all(network <- network(user), length <- integer(1..10)) do
      {network, :text}
      |> Stream.unfold(fn {network, input_type} ->
        next_model = model(input_type: input_type) |> pick()
        network = Panic.Engine.append_model!(network, next_model, actor: user)
        {network, {network, next_model.fetch!(:output_type)}}
      end)
      |> Enum.take(length)
      # return the last network (with the latest :models attr) from the generator
      |> Enum.at(-1)
    end
  end
end

defmodule Panic.Fixtures do
  @moduledoc """
  Test fixtures for Panic resources.
  """
  def user(password) do
    password
    |> StreamData.constant()
    |> Panic.Generators.user()
    |> ExUnitProperties.pick()
  end

  def user() do
    Panic.Generators.user()
    |> ExUnitProperties.pick()
  end
end

defmodule PanicWeb.Helpers do
  def create_and_sign_in_user(%{conn: conn}) do
    password = "abcd1234"

    user =
      password
      |> Panic.Fixtures.user()
      |> Panic.Generators.set_all_tokens()

    strategy = AshAuthentication.Info.strategy!(Panic.Accounts.User, :password)

    {:ok, user} =
      AshAuthentication.Strategy.action(strategy, :sign_in, %{
        email: user.email,
        password: password
      })

    %{
      conn:
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(user),
      user: user
    }
  end
end
