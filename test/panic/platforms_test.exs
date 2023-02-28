defmodule Panic.PlatformsTest do
  @moduledoc """
  Test the Platforms modules. These tests hit the actual APIs! So while it
  doesn't cost _much_, probably don't run them on your Emacs idle timer :)

  """
  use Panic.DataCase

  import Panic.AccountsFixtures
  alias Panic.Accounts
  alias Panic.Platforms
  alias Panic.Platforms.{OpenAI, Replicate, Vestaboard}

  @moduletag :real_platform_api_calls
  @moduletag timeout: 5 * 60 * 1000

  describe "Platform helpers" do
    test "return map of all model info Maps" do
      for %{name: name, description: description, input: input, output: output} <-
            Platforms.all_model_info() do
        assert is_binary(name)
        assert is_binary(description)
        assert input in [:text, :image, :audio]
        assert output in [:text, :image, :audio]
      end
    end

    test "list models" do
      assert is_list(Platforms.list_models())
    end

    test "get info for a single model" do
      ## manually cribbed from lib/panic/platforms/replicate.ex:57
      sd_info = %{
        name: "Stable Diffusion",
        description: "",
        input: :text,
        output: :image,
        path: "stability-ai/stable-diffusion"
      }

      assert Platforms.model_info("replicate:stability-ai/stable-diffusion") == sd_info
    end
  end

  describe "OpenAI" do
    setup [:create_user, :load_env_vars]

    test "davinci-instruct-beta responds when given a valid prompt", %{tokens: tokens} do
      input = "explain how a chicken would cross a road."

      {:ok, output} = OpenAI.create("openai:davinci-instruct-beta", input, tokens)
      assert is_binary(output)
    end

    test "text-davinci-003 responds when given a valid prompt", %{tokens: tokens} do
      input = "hello Leonardo, what's your middle name?"

      assert {:ok, output} = OpenAI.create("openai:text-davinci-003", input, tokens)
      assert is_binary(output)
    end

    test "text-ada-001 responds when given a valid prompt", %{tokens: tokens} do
      input = "what year did Ada Lovelace first visit the moon?"

      assert {:ok, output} = OpenAI.create("openai:text-ada-001", input, tokens)
      assert is_binary(output)
    end
  end

  describe "Replicate" do
    setup [:create_user, :load_env_vars]

    test "stable diffusion returns a URL (probably to an image, but untested here) when given a valid input",
         %{tokens: tokens} do
      input = "sheep grazing on a grassy meadow"

      assert {:ok, output} =
               Replicate.create("replicate:stability-ai/stable-diffusion", input, tokens)

      assert Regex.match?(~r|https://.*|, output)
    end

    test "stable diffusion NSFW filter works (this test isn't 100% reliable)",
         %{tokens: tokens} do
      # it sucks that we have to guard against this, but need to make sure the NSFW filter works
      input = "a sexy naked woman"

      assert {:error, :nsfw} =
               Replicate.create("replicate:stability-ai/stable-diffusion", input, tokens)
    end

    test "kyrick/prompt-parrot works", %{tokens: tokens} do
      input = "sheep grazing on a grassy meadow"
      assert {:ok, output} = Replicate.create("replicate:kyrick/prompt-parrot", input, tokens)
      assert String.starts_with?(output, input)
    end

    test "2feet6inches/cog-prompt-parrot works", %{tokens: tokens} do
      input = "sheep grazing on a grassy meadow"

      assert {:ok, output} =
               Replicate.create("replicate:2feet6inches/cog-prompt-parrot", input, tokens)

      assert String.starts_with?(output, input)
    end

    test "stable diffusion image -> rmokady/clip_prefix_caption cycle works",
         %{tokens: tokens} do
      input = "sheep grazing on a grassy meadow"

      assert {:ok, image_url} =
               Replicate.create("replicate:stability-ai/stable-diffusion", input, tokens)

      assert {:ok, image_caption} =
               Replicate.create("replicate:rmokady/clip_prefix_caption", image_url, tokens)

      assert is_binary(image_caption)
    end

    test "stable diffusion image -> BLIP2 cycle works", %{tokens: tokens} do
      input = "sheep grazing on a grassy meadow"

      assert {:ok, image_url} =
               Replicate.create("replicate:stability-ai/stable-diffusion", input, tokens)

      assert {:ok, image_caption} =
               Replicate.create("replicate:salesforce/blip-2", image_url, tokens)

      assert is_binary(image_caption)
    end

    test "stable diffusion image -> Instruct pix2pix cycle works", %{tokens: tokens} do
      input = "sheep grazing on a grassy meadow"

      assert {:ok, image_url} =
               Replicate.create("replicate:stability-ai/stable-diffusion", input, tokens)

      assert {:ok, output} =
               Replicate.create("replicate:timothybrooks/instruct-pix2pix", image_url, tokens)

      assert Regex.match?(~r|https://.*|, output)
    end

    test "stable diffusion image -> j-min/clip-caption-reward cycle works",
         %{tokens: tokens} do
      input = "sheep grazing on a grassy meadow"

      assert {:ok, image_url} =
               Replicate.create("replicate:stability-ai/stable-diffusion", input, tokens)

      assert {:ok, image_caption} =
               Replicate.create("replicate:j-min/clip-caption-reward", image_url, tokens)

      assert is_binary(image_caption)
    end
  end

  describe "Vestaboard" do
    setup [:create_user, :load_env_vars]

    test "list_subscriptions for Panic 1", %{tokens: tokens} do
      assert %{"subscriptions" => [_]} = Vestaboard.list_subscriptions("Panic 1", tokens)
    end

    test "send text to Panic 1 (for real, so make sure it's not doing something important)", %{
      tokens: tokens
    } do
      assert {:ok, _} =
               Vestaboard.send_text(
                 "Panic 1",
                 "ANU School of Cybernetics\n\n#{NaiveDateTime.utc_now() |> NaiveDateTime.to_string()}",
                 tokens
               )
    end
  end

  defp create_user(_context) do
    %{user: user_fixture()}
  end

  defp load_env_vars(%{user: user} = context) do
    insert_api_tokens_from_env(user.id)

    context
    |> Map.put(:tokens, Accounts.get_api_token_map(user.id))
  end
end
