defmodule Panic.PlatformsTest do
  @moduledoc """
  Test the Platforms modules. These tests hit the actual APIs! So while it
  doesn't cost _much_, probably don't run them on your Emacs idle timer :)

  """
  use Panic.DataCase

  import Panic.AccountsFixtures
  alias Panic.Platforms.{OpenAI, Replicate}

  describe "OpenAI" do
    test "davinci GPT3 responds when given a valid prompt" do
      user = user_fixture()
      insert_api_tokens_from_env(user)
      prompt = "why did the chicken cross the road?"

      output = OpenAI.create("davinci-instruct-beta", prompt, user)

      assert is_binary(output)
    end
  end
end
