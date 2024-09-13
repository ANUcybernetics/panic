defmodule Panic.ModelTest do
  use Panic.DataCase
  use ExUnitProperties
  alias Panic.Model

  describe "model generators" do
    property "generate models with correct attributes" do
      check all(
              text_input_model <- Panic.Generators.model(input_type: :text),
              image_ouput_model <- Panic.Generators.model(output_type: :image),
              replicate_model <- Panic.Generators.model(platform: Panic.Platforms.Replicate)
            ) do
        assert %Panic.Model{input_type: :text} = text_input_model
        assert %Panic.Model{output_type: :image} = image_ouput_model
        assert %Panic.Model{platform: Panic.Platforms.Replicate} = replicate_model
      end
    end

    property "filter models by input type" do
      check all(
              input_type <- one_of([:text, :image]),
              model <- Panic.Generators.model(input_type: input_type)
            ) do
        assert model.input_type == input_type
      end
    end
  end

  describe "Replicate models" do
    @describetag skip: "requires API keys"

    test "get latest StableDiffusion model version" do
      {:ok, version} =
        Panic.Platforms.Replicate.get_latest_model_version(Models.StableDiffusion, "bad token")

      assert String.match?(version, ~r/^[a-f0-9]{64}$/)
    end
  end

  describe "OpenAI models" do
    @describetag skip: "requires API keys"

    test "invoke text models with predefined response" do
      # models for which we have canned responses
      models =
        Panic.Platforms.OpenAI
        |> Model.all()
        |> Enum.filter(fn model -> model.input_type == :text end)

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
