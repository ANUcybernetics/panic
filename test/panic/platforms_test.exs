defmodule Panic.PlatformsTest do
  @moduledoc """
  Test the Platforms modules. These tests hit the actual APIs! So while it
  doesn't cost _much_, probably don't run them on your Emacs idle timer :)

  """
  use Panic.DataCase

  import Panic.AccountsFixtures
  alias Panic.Platforms.{OpenAI, Replicate}

  @moduletag :real_platform_api_calls

  describe "OpenAI" do
    setup [:create_user, :load_env_vars]

    test "davinci-instruct-beta responds when given a valid prompt", %{user: user} do
      input = "explain how a chicken would cross a road."

      {:ok, output} = OpenAI.create("davinci-instruct-beta", input, user)
      assert is_binary(output)
    end

    test "text-davinci-003 responds when given a valid prompt", %{user: user} do
      input = "hello Leonardo, what's your middle name?"

      assert {:ok, output} = OpenAI.create("text-davinci-003", input, user)
      assert is_binary(output)
    end

    test "text-ada-001 responds when given a valid prompt", %{user: user} do
      input = "what year did Ada Lovelace first visit the moon?"

      assert {:ok, output} = OpenAI.create("text-ada-001", input, user)
      assert is_binary(output)
    end
  end

  describe "Replicate" do
    setup [:create_user, :load_env_vars]

    test "stable diffusion returns a URL (probably to an image, but untested here) when given a valid input",
         %{user: user} do
      input = "sheep grazing on a grassy meadow"

      assert {:ok, output} = Replicate.create("stability-ai/stable-diffusion", input, user)
      assert Regex.match?(~r|https://.*|, output)
    end

    test "stable diffusion NSFW filter works (this test isn't 100% reliable)",
         %{user: user} do
      # it sucks that we have to guard against this, but need to make sure the NSFW filter works
      input = "a sexy naked woman"

      assert {:error, :nsfw} = Replicate.create("stability-ai/stable-diffusion", input, user)
    end

    test "kyrick/prompt-parrot works", %{user: user} do
      input = "sheep grazing on a grassy meadow"
      assert {:ok, output} = Replicate.create("kyrick/prompt-parrot", input, user)
      assert String.starts_with?(output, input)
    end

    test "2feet6inches/cog-prompt-parrot works", %{user: user} do
      input = "sheep grazing on a grassy meadow"
      assert {:ok, output} = Replicate.create("2feet6inches/cog-prompt-parrot", input, user)
      assert String.starts_with?(output, input)
    end

    test "stable diffusion image -> rmokady/clip_prefix_caption cycle works",
         %{user: user} do
      input = "sheep grazing on a grassy meadow"

      assert {:ok, image_url} = Replicate.create("stability-ai/stable-diffusion", input, user)

      assert {:ok, image_caption} =
               Replicate.create("rmokady/clip_prefix_caption", image_url, user)

      assert is_binary(image_caption)
    end

    test "stable diffusion image -> j-min/clip-caption-reward cycle works",
         %{user: user} do
      input = "sheep grazing on a grassy meadow"

      assert {:ok, image_url} = Replicate.create("stability-ai/stable-diffusion", input, user)
      assert {:ok, image_caption} = Replicate.create("j-min/clip-caption-reward", image_url, user)
      assert is_binary(image_caption)
    end
  end

  defp create_user(_context) do
    %{user: user_fixture()}
  end

  defp load_env_vars(%{user: user} = context) do
    insert_api_tokens_from_env(user.id)
    context
  end
end
