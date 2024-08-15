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
    property "model generators work" do
      check all(
              model <- Panic.Generators.model(),
              text_input_model <- Panic.Generators.model(input_type: :text),
              image_ouput_model <- Panic.Generators.model(output_type: :image),
              replicate_model <- Panic.Generators.model(platform: Panic.Platforms.Replicate)
            ) do
        assert %Panic.Models.ModelInfo{} = model.info()
        assert text_input_model.fetch!(:input_type) == :text
        assert image_ouput_model.fetch!(:output_type) == :image
        assert replicate_model.fetch!(:platform) == Panic.Platforms.Replicate
      end
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
      {:ok, version} = Panic.Platforms.Replicate.get_latest_model_version(Models.StableDiffusion)
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
