defmodule Panic.Platforms.DummyTest do
  @moduledoc """
  Tests for the Dummy platform module to ensure it works correctly for all input/output combinations

  Verifies deterministic behavior and proper integration with the rest of the system
  """

  use Panic.DataCase

  alias Panic.Model
  alias Panic.Platforms.Dummy

  describe "Dummy.invoke/3" do
    test "text-to-text transformation" do
      model = %Model{
        id: "dummy-t2t",
        name: "Test Text-to-Text",
        platform: Dummy,
        path: "dummy/text-to-text",
        input_type: :text,
        output_type: :text,
        invoke: fn _, _, _ -> {:ok, "dummy"} end
      }

      assert {:ok, "DUMMY_TEXT: " <> reversed} = Dummy.invoke(model, "hello world", "token")
      assert reversed == String.reverse("hello world")
    end

    test "text-to-image generation" do
      model = %Model{
        id: "dummy-t2i",
        name: "Test Text-to-Image",
        platform: Dummy,
        path: "dummy/text-to-image",
        input_type: :text,
        output_type: :image,
        invoke: fn _, _, _ -> {:ok, "dummy"} end
      }

      assert {:ok, url} = Dummy.invoke(model, "generate an image", "token")
      assert String.starts_with?(url, "https://dummy-images.test/")
      assert String.ends_with?(url, ".png")
    end

    test "text-to-audio generation" do
      model = %Model{
        id: "dummy-t2a",
        name: "Test Text-to-Audio",
        platform: Dummy,
        path: "dummy/text-to-audio",
        input_type: :text,
        output_type: :audio,
        invoke: fn _, _, _ -> {:ok, "dummy"} end
      }

      assert {:ok, url} = Dummy.invoke(model, "generate audio", "token")
      assert String.starts_with?(url, "https://dummy-audio.test/")
      assert String.ends_with?(url, ".ogg")
    end

    test "image-to-text captioning" do
      model = %Model{
        id: "dummy-i2t",
        name: "Test Image-to-Text",
        platform: Dummy,
        path: "dummy/image-to-text",
        input_type: :image,
        output_type: :text,
        invoke: fn _, _, _ -> {:ok, "dummy"} end
      }

      # Test with a dummy image URL
      assert {:ok, caption} = Dummy.invoke(model, "https://dummy-images.test/abc123.png", "token")
      assert String.starts_with?(caption, "DUMMY_CAPTION:")
      assert String.contains?(caption, "abc123")

      # Test with a regular image URL
      assert {:ok, caption2} = Dummy.invoke(model, "https://example.com/image.jpg", "token")
      assert String.starts_with?(caption2, "DUMMY_CAPTION:")
      assert String.contains?(caption2, "descriptive caption")
    end

    test "image-to-image transformation" do
      model = %Model{
        id: "dummy-i2i",
        name: "Test Image-to-Image",
        platform: Dummy,
        path: "dummy/image-to-image",
        input_type: :image,
        output_type: :image,
        invoke: fn _, _, _ -> {:ok, "dummy"} end
      }

      assert {:ok, url} = Dummy.invoke(model, "https://example.com/input.png", "token")
      assert String.starts_with?(url, "https://dummy-images.test/transformed_")
      assert String.ends_with?(url, ".png")
    end

    test "image-to-audio generation" do
      model = %Model{
        id: "dummy-i2a",
        name: "Test Image-to-Audio",
        platform: Dummy,
        path: "dummy/image-to-audio",
        input_type: :image,
        output_type: :audio,
        invoke: fn _, _, _ -> {:ok, "dummy"} end
      }

      assert {:ok, url} = Dummy.invoke(model, "https://example.com/input.png", "token")
      assert String.starts_with?(url, "https://dummy-audio.test/from_image_")
      assert String.ends_with?(url, ".ogg")
    end

    test "audio-to-text transcription" do
      model = %Model{
        id: "dummy-a2t",
        name: "Test Audio-to-Text",
        platform: Dummy,
        path: "dummy/audio-to-text",
        input_type: :audio,
        output_type: :text,
        invoke: fn _, _, _ -> {:ok, "dummy"} end
      }

      # Test with direct audio URL
      assert {:ok, transcript} = Dummy.invoke(model, "https://example.com/audio.ogg", "token")
      assert String.starts_with?(transcript, "DUMMY_TRANSCRIPT:")

      # Test with Gemini-style input (map with audio_file key)
      assert {:ok, transcript2} =
               Dummy.invoke(model, %{audio_file: "https://example.com/audio2.ogg"}, "token")

      assert String.starts_with?(transcript2, "DUMMY_TRANSCRIPT:")

      # Test with Gemini-style input including prompt
      assert {:ok, description} =
               Dummy.invoke(
                 model,
                 %{audio_file: "https://example.com/audio3.ogg", prompt: "Describe the mood"},
                 "token"
               )

      assert String.starts_with?(description, "DUMMY_DESCRIPTION:")
      assert String.contains?(description, "Describe the mood")
    end

    test "audio-to-image generation" do
      model = %Model{
        id: "dummy-a2i",
        name: "Test Audio-to-Image",
        platform: Dummy,
        path: "dummy/audio-to-image",
        input_type: :audio,
        output_type: :image,
        invoke: fn _, _, _ -> {:ok, "dummy"} end
      }

      assert {:ok, url} = Dummy.invoke(model, "https://example.com/audio.ogg", "token")
      assert String.starts_with?(url, "https://dummy-images.test/from_audio_")
      assert String.ends_with?(url, ".png")
    end

    test "audio-to-audio transformation" do
      model = %Model{
        id: "dummy-a2a",
        name: "Test Audio-to-Audio",
        platform: Dummy,
        path: "dummy/audio-to-audio",
        input_type: :audio,
        output_type: :audio,
        invoke: fn _, _, _ -> {:ok, "dummy"} end
      }

      assert {:ok, url} = Dummy.invoke(model, "https://example.com/audio.ogg", "token")
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

    test "outputs are deterministic" do
      model = %Model{
        id: "dummy-t2t",
        name: "Test Text-to-Text",
        platform: Dummy,
        path: "dummy/text-to-text",
        input_type: :text,
        output_type: :text,
        invoke: fn _, _, _ -> {:ok, "dummy"} end
      }

      input = "test input"

      # Call multiple times with same input
      {:ok, output1} = Dummy.invoke(model, input, "token1")
      {:ok, output2} = Dummy.invoke(model, input, "token2")
      {:ok, output3} = Dummy.invoke(model, input, "different_token")

      # All outputs should be identical
      assert output1 == output2
      assert output2 == output3
    end
  end

  describe "integration with Model module" do
    test "all dummy models are properly configured" do
      dummy_models = Model.all(platform: Dummy)

      # All 9 input/output combinations
      assert length(dummy_models) == 9

      for model <- dummy_models do
        assert model.platform == Dummy
        assert model.path =~ ~r/^dummy\//
        assert model.description =~ ~r/Dummy model for testing/
        assert is_function(model.invoke, 3)
      end
    end

    test "dummy models can be invoked through their invoke function" do
      for model <- Model.all(platform: Dummy) do
        input =
          case model.input_type do
            :text -> "test text"
            :image -> "https://example.com/test.png"
            :audio -> "https://example.com/test.ogg"
          end

        assert {:ok, output} = model.invoke.(model, input, nil)

        case model.output_type do
          :text -> assert is_binary(output) and String.contains?(output, "DUMMY_")
          :image -> assert String.starts_with?(output, "https://dummy-images.test/")
          :audio -> assert String.starts_with?(output, "https://dummy-audio.test/")
        end
      end
    end
  end
end
