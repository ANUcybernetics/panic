ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Panic.Repo, :manual)

defmodule Panic.Generators do
  @moduledoc """
  StreamData generators for Panic resources.
  """
  use ExUnitProperties

  def model(filters \\ []) do
    StreamData.one_of(Panic.Models.list())
    |> filter(fn model ->
      filters
      |> Enum.map(fn {output, type} -> model.fetch!(output) == type end)
      |> Enum.all?()
    end)
  end

  def network(user, opts \\ []) do
    gen all(
          input <-
            Ash.Generator.action_input(Panic.Engine.Network, :create, %{
              models:
                list_of(
                  StreamData.member_of(Panic.Models.list()),
                  opts
                )
            })
        ) do
      Panic.Engine.Network
      |> Ash.Changeset.for_create(:create, input, actor: user)
      |> Ash.create!()
    end
  end

  def first_invocation(user) do
    gen all(
          input <-
            Ash.Generator.action_input(Panic.Engine.Invocation, :prepare_first, %{
              # need at least one, otherwise Panic.Changes.Invoke will raise
              network: network(user, min_length: 1)
            })
        ) do
      Panic.Engine.Invocation
      |> Ash.Changeset.for_create(:prepare_first, input)
      |> Ash.create!()
    end
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

  def user do
    gen all(email <- email(), password <- password()) do
      Panic.Accounts.User
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{email: email, password: password, password_confirmation: password}
      )
      |> Ash.create!()
    end
  end

  def user_fixture() do
    user() |> pick()
  end

  def user_with_real_tokens_fixture() do
    user = user_fixture()
    replicate_token = Application.get_env(:panic, :api_tokens, :replicate)
    openai_token = Application.get_env(:panic, :api_tokens, :openai)

    Panic.Accounts.create_api_token!(:replicate, replicate_token, actor: user)
    Panic.Accounts.create_api_token!(:openai, openai_token, actor: user)

    user
  end
end
