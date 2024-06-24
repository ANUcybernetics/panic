ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Panic.Repo, :manual)

defmodule Panic.Generators do
  @moduledoc """
  StreamData generators for Panic resources.
  """
  use ExUnitProperties

  def network(opts \\ []) do
    gen all(
          input <-
            Ash.Generator.action_input(Panic.Engine.Network, :create, %{
              models:
                list_of(
                  StreamData.member_of([
                    Panic.Models.SDXL,
                    Panic.Models.BLIP2,
                    Panic.Models.GPT4o
                  ]),
                  opts
                )
            })
        ) do
      Panic.Engine.Network
      |> Ash.Changeset.for_create(:create, input)
      |> Ash.create!()
    end
  end

  def invocation do
    gen all(
          input <-
            Ash.Generator.action_input(Panic.Engine.Invocation, :create_first, %{
              # need at least one, otherwise Panic.Changes.Invoke will raise
              network: network(min_length: 1)
            })
        ) do
      Panic.Engine.Invocation
      |> Ash.Changeset.for_create(:create_first, input)
      |> Ash.create!()
    end
  end

  def password do
    string(:utf8, min_length: 8)
    |> filter(fn s -> not Regex.match?(~r/^[[:space:]]*$/, s) end)
    |> filter(fn s -> String.length(s) >= 8 end)
  end

  def user do
    gen all(
          email <- Ash.Generator.sequence(:unique_email, fn i -> "user-#{i}@example.com" end),
          password <- password()
        ) do
      Panic.Accounts.User
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{email: email, password: password, password_confirmation: password}
      )
      |> Ash.create!()
    end
  end
end
