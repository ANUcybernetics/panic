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

  describe "all platforms" do
    test "have models with unique ids" do
      model_ids =
        Enum.map(Model.all(), fn %Panic.Model{id: id} -> id end)

      unique_ids = Enum.uniq(model_ids)

      assert length(model_ids) == length(unique_ids), "all model IDs should be unique"
    end
  end

  describe "Replicate platform" do
    alias Panic.Platforms.Replicate

    @describetag skip: "requires API keys"
    @describetag timeout: 300_000

    test "can list latest model version for all models" do
      user = Panic.Fixtures.user_with_tokens()
      models = Model.all(platform: Replicate)

      for model <- models do
        assert {:ok, version} = Replicate.get_latest_model_version(model, user.replicate_token)
        assert String.match?(version, ~r/^[a-f0-9]{64}$/)
      end
    end

    test "can generate a stable diffusion image" do
      user = Panic.Fixtures.user_with_tokens()
      %Model{invoke: invoke_fn} = model = Model.by_id!("stable-diffusion-test")

      {:ok, img_url} =
        invoke_fn.(model, "I could eat a peach for hours.", user.replicate_token)

      assert String.match?(img_url, ~r|^https://.*$|)
    end

    test "can successfully invoke all models" do
      user = Panic.Fixtures.user_with_tokens()
      models = Model.all(platform: Replicate)

      for %Model{id: id, invoke: invoke_fn} = model <- models do
        IO.puts("invoking #{id}")

        input =
          case model do
            %Model{input_type: :text} -> "describe a nice scene"
            %Model{input_type: :image} -> "https://picsum.photos/400/225/"
          end

        assert {:ok, output} = invoke_fn.(model, input, user.replicate_token)
        # assert output is not blank
        assert String.match?(output, ~r/\S/)
      end
    end
  end

  describe "OpenAI platform" do
    alias Panic.Platforms.OpenAI

    @describetag skip: "requires API keys"

    test "generates the right* answer for all models" do
      # models for which we have canned responses
      user = Panic.Fixtures.user_with_tokens()
      models = Model.all(platform: OpenAI)

      for model <- models do
        assert {:ok, output} =
                 OpenAI.invoke(
                   model,
                   "Respond with just the word 'bananaphone'. Do not include any other content (even punctuation).",
                   user.openai_token
                 )

        assert output == "bananaphone"
      end
    end
  end
end
