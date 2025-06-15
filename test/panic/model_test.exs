defmodule Panic.ModelTest do
  use Panic.DataCase
  use ExUnitProperties

  alias Panic.Model
  alias Panic.Platforms.OpenAI
  alias Panic.Platforms.Replicate

  describe "model generators" do
    property "generate models with correct attributes" do
      check all(
              text_input_model <- Panic.Generators.model(input_type: :text),
              image_ouput_model <- Panic.Generators.model(output_type: :image),
              replicate_model <- Panic.Generators.real_model(platform: Replicate)
            ) do
        assert %Panic.Model{input_type: :text} = text_input_model
        assert %Panic.Model{output_type: :image} = image_ouput_model
        assert %Panic.Model{platform: Replicate} = replicate_model
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

  describe "Model.all/0 and Model.all/1" do
    test "have models with unique ids" do
      # This includes all models: real platforms (OpenAI, Replicate, etc.) and dummy models
      model_ids =
        Enum.map(Model.all(), fn %Panic.Model{id: id} -> id end)

      unique_ids = Enum.uniq(model_ids)

      assert length(model_ids) == length(unique_ids), "all model IDs should be unique"
    end

    test "filters models by platform" do
      dummy_models = Model.all(platform: Panic.Platforms.Dummy)
      openai_models = Model.all(platform: OpenAI)
      replicate_models = Model.all(platform: Replicate)

      # All dummy models should be from Dummy platform
      for model <- dummy_models do
        assert model.platform == Panic.Platforms.Dummy
      end

      # All OpenAI models should be from OpenAI platform
      for model <- openai_models do
        assert model.platform == OpenAI
      end

      # All Replicate models should be from Replicate platform
      for model <- replicate_models do
        assert model.platform == Replicate
      end
    end
  end

  describe "Model.by_id!/1" do
    test "retrieves specific models by ID" do
      # Test with a known dummy model
      model = Model.by_id!("dummy-t2t")
      assert model.id == "dummy-t2t"
      assert model.platform == Panic.Platforms.Dummy
      assert model.input_type == :text
      assert model.output_type == :text
    end

    test "raises for unknown model ID" do
      assert_raise RuntimeError, fn ->
        Model.by_id!("nonexistent-model")
      end
    end
  end

  describe "Model utility functions" do
    test "model_url/1 returns correct URLs for different platforms" do
      dummy_model = Model.by_id!("dummy-t2t")
      assert Model.model_url(dummy_model) == "#dummy-platform"

      # Test with other platform models (without API calls)
      openai_models = Model.all(platform: OpenAI)

      if length(openai_models) > 0 do
        openai_model = hd(openai_models)
        url = Model.model_url(openai_model)
        assert String.starts_with?(url, "https://")
      end
    end

    test "model_ids_to_model_list/1 converts IDs to models" do
      model_ids = ["dummy-t2t", "dummy-i2t"]
      models = Model.model_ids_to_model_list(model_ids)

      assert length(models) == 2
      assert Enum.map(models, & &1.id) == model_ids
    end

    test "model_list_to_model_ids/1 converts models to IDs" do
      models = [Model.by_id!("dummy-t2t"), Model.by_id!("dummy-i2t")]
      model_ids = Model.model_list_to_model_ids(models)

      assert model_ids == ["dummy-t2t", "dummy-i2t"]
    end

    test "models_with_indices/1 adds indices to models" do
      models = [Model.by_id!("dummy-t2t"), Model.by_id!("dummy-i2t")]
      indexed_models = Model.models_with_indices(models)

      assert indexed_models == [
               {0, 0, Model.by_id!("dummy-t2t")},
               {1, 1, Model.by_id!("dummy-i2t")}
             ]
    end
  end

  describe "Dummy platform models" do
    alias Panic.Platforms.Dummy

    test "all dummy models have correct input/output type combinations" do
      dummy_models = Model.all(platform: Dummy)

      expected_combinations = [
        {"dummy-t2t", :text, :text},
        {"dummy-t2i", :text, :image},
        {"dummy-t2a", :text, :audio},
        {"dummy-i2t", :image, :text},
        {"dummy-i2i", :image, :image},
        {"dummy-i2a", :image, :audio},
        {"dummy-a2t", :audio, :text},
        {"dummy-a2i", :audio, :image},
        {"dummy-a2a", :audio, :audio}
      ]

      # Verify we have exactly 9 dummy models
      assert length(dummy_models) == 9

      for {id, input_type, output_type} <- expected_combinations do
        model = Enum.find(dummy_models, &(&1.id == id))
        assert model != nil, "Model #{id} should exist"
        assert model.input_type == input_type, "Model #{id} should have input_type #{input_type}"
        assert model.output_type == output_type, "Model #{id} should have output_type #{output_type}"
        assert model.platform == Dummy
        assert model.path =~ ~r/^dummy\//
        assert model.description =~ ~r/Dummy model for testing/
        assert is_function(model.invoke, 3)
      end
    end

    test "dummy models produce deterministic outputs" do
      dummy_models = Model.all(platform: Dummy)

      for %Model{invoke: invoke_fn} = model <- dummy_models do
        input = test_input_for_type(model.input_type)

        # Invoke the model twice with the same input
        {:ok, output1} = invoke_fn.(model, input, nil)
        {:ok, output2} = invoke_fn.(model, input, nil)

        # Outputs should be identical
        assert output1 == output2, "Model #{model.id} should produce deterministic output"

        # Outputs should contain expected markers
        case model.output_type do
          :text -> assert String.contains?(output1, "DUMMY_")
          :image -> assert String.starts_with?(output1, "https://dummy-images.test/")
          :audio -> assert String.starts_with?(output1, "https://dummy-audio.test/")
        end
      end
    end

    test "dummy models can be invoked through their invoke function" do
      for model <- Model.all(platform: Dummy) do
        input = test_input_for_type(model.input_type)

        assert {:ok, output} = model.invoke.(model, input, nil)

        case model.output_type do
          :text -> assert is_binary(output) and String.contains?(output, "DUMMY_")
          :image -> assert String.starts_with?(output, "https://dummy-images.test/")
          :audio -> assert String.starts_with?(output, "https://dummy-audio.test/")
        end
      end
    end

    test "text-to-text transformation produces reversed text" do
      model = Model.by_id!("dummy-t2t")
      input = "hello world"

      assert {:ok, "DUMMY_TEXT: " <> reversed} = model.invoke.(model, input, "token")
      assert reversed == String.reverse(input)
    end

    test "text-to-image generation produces proper URL" do
      model = Model.by_id!("dummy-t2i")
      input = "generate an image"

      assert {:ok, url} = model.invoke.(model, input, "token")
      assert String.starts_with?(url, "https://dummy-images.test/")
      assert String.ends_with?(url, ".png")
    end

    test "text-to-audio generation produces proper URL" do
      model = Model.by_id!("dummy-t2a")
      input = "generate audio"

      assert {:ok, url} = model.invoke.(model, input, "token")
      assert String.starts_with?(url, "https://dummy-audio.test/")
      assert String.ends_with?(url, ".ogg")
    end

    test "image-to-text captioning handles different image URLs" do
      model = Model.by_id!("dummy-i2t")

      # Test with a dummy image URL
      assert {:ok, caption} = model.invoke.(model, "https://dummy-images.test/abc123.png", "token")
      assert String.starts_with?(caption, "DUMMY_CAPTION:")
      assert String.contains?(caption, "abc123")

      # Test with a regular image URL
      assert {:ok, caption2} = model.invoke.(model, "https://example.com/image.jpg", "token")
      assert String.starts_with?(caption2, "DUMMY_CAPTION:")
      assert String.contains?(caption2, "descriptive caption")
    end

    test "image-to-image transformation produces proper URL" do
      model = Model.by_id!("dummy-i2i")
      input = "https://example.com/input.png"

      assert {:ok, url} = model.invoke.(model, input, "token")
      assert String.starts_with?(url, "https://dummy-images.test/transformed_")
      assert String.ends_with?(url, ".png")
    end

    test "image-to-audio generation produces proper URL" do
      model = Model.by_id!("dummy-i2a")
      input = "https://example.com/input.png"

      assert {:ok, url} = model.invoke.(model, input, "token")
      assert String.starts_with?(url, "https://dummy-audio.test/from_image_")
      assert String.ends_with?(url, ".ogg")
    end

    test "audio-to-text transcription handles different input formats" do
      model = Model.by_id!("dummy-a2t")

      # Test with direct audio URL
      assert {:ok, transcript} = model.invoke.(model, "https://example.com/audio.ogg", "token")
      assert String.starts_with?(transcript, "DUMMY_TRANSCRIPT:")

      # Test with Gemini-style input (map with audio_file key)
      assert {:ok, transcript2} =
               model.invoke.(model, %{audio_file: "https://example.com/audio2.ogg"}, "token")

      assert String.starts_with?(transcript2, "DUMMY_TRANSCRIPT:")

      # Test with Gemini-style input including prompt
      assert {:ok, description} =
               model.invoke.(
                 model,
                 %{audio_file: "https://example.com/audio3.ogg", prompt: "Describe the mood"},
                 "token"
               )

      assert String.starts_with?(description, "DUMMY_DESCRIPTION:")
      assert String.contains?(description, "Describe the mood")
    end

    test "audio-to-image generation produces proper URL" do
      model = Model.by_id!("dummy-a2i")
      input = "https://example.com/audio.ogg"

      assert {:ok, url} = model.invoke.(model, input, "token")
      assert String.starts_with?(url, "https://dummy-images.test/from_audio_")
      assert String.ends_with?(url, ".png")
    end

    test "audio-to-audio transformation produces proper URL" do
      model = Model.by_id!("dummy-a2a")
      input = "https://example.com/audio.ogg"

      assert {:ok, url} = model.invoke.(model, input, "token")
      assert String.starts_with?(url, "https://dummy-audio.test/transformed_")
      assert String.ends_with?(url, ".ogg")
    end

    test "returns error for unsupported type combinations" do
      # Create a model with an invalid type combination (this shouldn't exist in practice)
      model = %Model{
        id: "invalid",
        name: "Test Invalid",
        platform: Dummy,
        path: "dummy/invalid",
        input_type: :invalid,
        output_type: :text,
        invoke: fn _, _, _ -> {:ok, "dummy"} end
      }

      assert {:error, message} = Dummy.invoke(model, "input", "token")
      assert String.contains?(message, "Unsupported dummy conversion")
    end

    test "outputs are deterministic across different tokens" do
      model = Model.by_id!("dummy-t2t")
      input = "test input"

      # Call multiple times with same input but different tokens
      {:ok, output1} = model.invoke.(model, input, "token1")
      {:ok, output2} = model.invoke.(model, input, "token2")
      {:ok, output3} = model.invoke.(model, input, "different_token")

      # All outputs should be identical
      assert output1 == output2
      assert output2 == output3
    end
  end

  # Helper function to generate appropriate test input based on input type
  defp test_input_for_type(:text), do: "test text input"
  defp test_input_for_type(:image), do: "https://example.com/test.png"
  defp test_input_for_type(:audio), do: "https://example.com/test.ogg"
end
