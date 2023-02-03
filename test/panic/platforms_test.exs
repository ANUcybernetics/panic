defmodule Panic.PlatformsTest do
  @moduledoc """
  Test the Platforms modules. These tests hit the actual APIs! So while it
  doesn't cost _much_, probably don't run them on your Emacs idle timer :)

  """
  use Panic.DataCase

  import Panic.AccountsFixtures
  alias Panic.Platforms.{OpenAI, Replicate}

  describe "OpenAI" do
    setup [:create_user, :load_env_vars]

    test "davinci-instruct-beta responds when given a valid prompt", %{user: user} do
      input = "explain how a chicken would cross a road."

      output = OpenAI.create("davinci-instruct-beta", input, user)

      IO.inspect(input <> output)
      assert is_binary(output)
    end

    test "text-davinci-003 responds when given a valid prompt", %{user: user} do
      input = "hello Leonardo, what's your middle name?"

      output = OpenAI.create("text-davinci-003", input, user)

      IO.inspect(input <> output)
      assert is_binary(output)
    end

    test "text-ada-001 responds when given a valid prompt", %{user: user} do
      input = "what year did Ada Lovelace first visit the moon?"

      output = OpenAI.create("text-ada-001", input, user)

      IO.inspect(input <> output)
      assert is_binary(output)
    end
  end

  defp create_user(_context) do
    %{user: user_fixture()}
  end

  defp load_env_vars(%{user: user} = context) do
    insert_api_tokens_from_env(user)
    context
  end
end
