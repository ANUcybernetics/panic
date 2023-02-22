defmodule Panic.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Panic.Accounts` context.
  """

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Panic.Accounts.register_user()

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  @doc """
  Generate a api_token.

  When `attrs` is empty the generated token won't be a real one, but it's a
  plausible Replicate token.

  """
  def api_token_fixture(attrs \\ %{}) do
    user = user_fixture()

    {:ok, api_token} =
      Map.merge(
        %{
          name: "Replicate",
          token: "laskdSLKJhdfaslsdkajfk65456",
          user_id: user.id
        },
        attrs
      )
      |> Panic.Accounts.create_api_token()

    api_token
  end

  def insert_api_tokens_from_env(user_id) do
    {:ok, _token} =
      Panic.Accounts.create_api_token(%{
        name: "OpenAI",
        token: System.get_env("OPENAI_API_TOKEN"),
        user_id: user_id
      })

    {:ok, _token} =
      Panic.Accounts.create_api_token(%{
        name: "Replicate",
        token: System.get_env("REPLICATE_API_TOKEN"),
        user_id: user_id
      })

    {:ok, _token} =
      Panic.Accounts.create_api_token(%{
        name: "Panic 1",
        token:
          "ba16996e-154f-4f31-83b7-ae0a8f13ecaf:d7b69bfe-1d60-4e8d-a36f-5ecb78fa70a0:880d3547-6cef-4f36-a81b-2ab0b7120505:" <>
            System.get_env("VESTABOARD_API_SECRET_1"),
        user_id: user_id
      })
  end
end
