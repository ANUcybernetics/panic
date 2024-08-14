defmodule Panic.ModelsTest do
  use Panic.DataCase
  use ExUnitProperties
  alias Panic.Models

  # setup do
  #   user = Panic.Fixtures.user()
  #   # set the real token, for "live" tests
  #   token = System.get_env("OPENAI_API_TOKEN")
  #   Panic.Accounts.create_api_token!(:openai, token, actor: user)

  #   {:ok, user: user}
  # end

  describe "model helpers" do
    test "list all modules which conform to Model behaviour" do
      models = [
        Models.BLIP2,
        Models.StableDiffusion,
        Models.ClipCaptionReward,
        Models.GPT4o,
        Models.CogPromptParrot,
        Models.GPT4Turbo,
        Models.LLaVA,
        Models.ClipPrefixCaption,
        Models.SDXL,
        Models.GPT4,
        Models.LLaMa3Instruct8B
      ]

      # check that they're all in the list
      assert Models.list() |> MapSet.new() == MapSet.new(models)
    end

    test "model list filters work" do
      text_input_model = Panic.Generators.model(input_type: :text) |> pick()
      assert text_input_model.fetch!(:input_type) == :text
      image_ouput_model = Panic.Generators.model(output_type: :image) |> pick()
      assert image_ouput_model.fetch!(:output_type) == :image

      replicate_ouput_model =
        Panic.Generators.model(platform: Panic.Platforms.Replicate) |> pick()

      assert replicate_ouput_model.fetch!(:platform) == Panic.Platforms.Replicate
    end

    property "model list filters work" do
      check all(
              input_type <- one_of([:text, :image]),
              model <- Panic.Generators.model(input_type: input_type)
            ) do
        assert model.fetch!(:input_type) == input_type
      end
    end
  end

  describe "Replicate models" do
    @describetag skip: "requires API keys"

    test "list models" do
      version = Panic.Platforms.Replicate.get_latest_model_version(Models.StableDiffusion)
      assert String.match?(version, ~r/^[a-f0-9]{64}$/)
    end

    @tag skip: "costs money"
    test "OpenAI models" do
      # models for which we have canned responses
      models =
        Panic.Platforms.OpenAI
        |> Models.list()
        |> Enum.filter(fn model -> model.fetch!(:input_type) == :text end)

      for model <- models do
        assert {:ok, output} =
                 model.invoke(
                   "Respond with just the word 'bananaphone'. Do not include any other content (even punctuation)."
                 )

        assert output == "bananaphone"
      end
    end
  end
end
