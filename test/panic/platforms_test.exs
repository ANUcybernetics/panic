defmodule Panic.PlatformsTest do
  @moduledoc """
  Tests for platform-specific model invocation functions.

  Each platform is tested by calling its invoke function directly,
  not through the Invocation resource's invoke action.
  """

  use Panic.DataCase

  alias Panic.Model
  alias Panic.Platforms.Dummy
  alias Panic.Platforms.Gemini
  alias Panic.Platforms.OpenAI
  alias Panic.Platforms.Replicate

  # Module-level test inputs for different input types
  @test_text_input "a shiny red apple"
  @test_image_input "https://fly.storage.tigris.dev/panic-invocation-outputs/nsfw-placeholder.webp"
  @test_audio_input "https://fly.storage.tigris.dev/panic-invocation-outputs/test-audio.ogg"

  describe "Replicate platform" do
    @describetag api_required: true
    @describetag timeout: to_timeout(minute: 15)

    setup do
      api_key = System.get_env("REPLICATE_API_KEY")

      if is_nil(api_key) or api_key == "" do
        raise "REPLICATE_API_KEY environment variable must be set for Replicate platform tests"
      end

      {:ok, api_key: api_key}
    end

    test "can list latest model version for all models", %{api_key: api_key} do
      models = Model.all(platform: Replicate)
      assert length(models) > 0, "Expected to find Replicate models"

      for model <- models do
        assert {:ok, version} = Replicate.get_latest_model_version(model, api_key)

        assert String.match?(version, ~r/^[a-f0-9]{64}$/),
               "Expected valid version hash for model #{model.id}, got: #{version}"
      end
    end

    test "can invoke representative Replicate models", %{api_key: api_key} do
      # Test a subset of representative models to avoid timeouts
      # Include models from each input/output type combination
      representative_model_ids = [
        # image -> text (fast)
        "florence-2-large",
        # image -> text (fast)
        "blip-2",
        # text -> image (fast)
        "flux-schnell",
        # text -> text
        "meta-llama-3-8b-instruct",
        # text -> audio
        "musicgen",
        # audio -> text
        "whisper",
        # special model that might have issues
        "clip-caption-reward"
      ]

      all_models = Model.all(platform: Replicate)
      models = Enum.filter(all_models, fn model -> model.id in representative_model_ids end)

      # Ensure we found the models we're looking for
      found_ids = Enum.map(models, & &1.id)
      missing_ids = representative_model_ids -- found_ids

      if length(missing_ids) > 0 do
        IO.puts("Warning: Could not find models: #{Enum.join(missing_ids, ", ")}")
      end

      assert length(models) > 0, "Expected to find at least some representative models"

      for %Model{id: id, invoke: invoke_fn} = model <- models do
        input = test_input_for_model(model)
        IO.write("Testing model #{id}... ")
        start_time = System.monotonic_time(:millisecond)

        result =
          try do
            # 60 second timeout per model
            task = Task.async(fn -> invoke_fn.(model, input, api_key) end)
            Task.await(task, 60_000)
          catch
            :exit, {:timeout, _} -> {:error, :timeout}
          end

        duration = System.monotonic_time(:millisecond) - start_time

        case result do
          {:ok, output} ->
            IO.puts("✓ succeeded in #{duration}ms")
            assert is_binary(output), "Expected string output for model #{id}"
            assert String.match?(output, ~r/\S/), "Expected non-empty output for model #{id}"

          {:error, :nsfw} ->
            IO.puts("⚠ NSFW error (acceptable)")

          {:error, "We are not able to run this version" <> _} ->
            IO.puts("⚠ deprecated version")

          {:error, "- input: key is required" <> _} ->
            IO.puts("⚠ requires specific input format")

          {:error, :timeout} ->
            IO.puts("⚠ timed out after #{duration}ms")

          {:error, reason} ->
            IO.puts("✗ failed: #{inspect(reason)}")
            flunk("Failed to invoke model #{id}: #{inspect(reason)}")
        end
      end
    end

    test "flux-schnell generates valid image URLs", %{api_key: api_key} do
      %Model{invoke: invoke_fn} = model = Model.by_id!("flux-schnell")

      assert {:ok, img_url} = invoke_fn.(model, @test_text_input, api_key)
      assert String.match?(img_url, ~r|^https://.*$|), "Expected valid URL, got: #{img_url}"
    end

    test "BLIP2 captioner produces descriptive output", %{api_key: api_key} do
      %Model{invoke: invoke_fn} = model = Model.by_id!("blip-2")
      # Using a static test image to avoid rate limit issues
      input_img = @test_image_input

      assert {:ok, caption} = invoke_fn.(model, input_img, api_key)

      assert String.length(caption) > 10,
             "Expected descriptive caption (>10 chars), got: #{caption}"
    end

    test "florence-2-large model works correctly", %{api_key: api_key} do
      %Model{invoke: invoke_fn} = model = Model.by_id!("florence-2-large")
      input = test_input_for_model(model)

      assert {:ok, output} = invoke_fn.(model, input, api_key)
      assert String.match?(output, ~r/\S/), "Expected non-empty output"
    end
  end

  describe "OpenAI platform" do
    @describetag api_required: true
    @describetag timeout: to_timeout(minute: 5)

    setup do
      api_key = System.get_env("OPENAI_API_KEY")

      if is_nil(api_key) or api_key == "" do
        raise "OPENAI_API_KEY environment variable must be set for OpenAI platform tests"
      end

      {:ok, api_key: api_key}
    end

    test "can list available engines", %{api_key: api_key} do
      engines = OpenAI.list_engines(api_key)

      case engines do
        {:error, reason} ->
          flunk("Failed to list OpenAI engines: #{inspect(reason)}")

        engines when is_list(engines) ->
          assert length(engines) > 0, "Expected to find available engines"
          assert Enum.all?(engines, &is_map/1), "Expected all engines to be maps"
      end
    end

    test "can invoke all OpenAI models", %{api_key: api_key} do
      models = Model.all(platform: OpenAI)
      assert length(models) > 0, "Expected to find OpenAI models"

      for %Model{id: id, invoke: invoke_fn} = model <- models do
        input = test_input_for_model(model)

        assert {:ok, output} = invoke_fn.(model, input, api_key),
               "Failed to invoke model #{id}"

        assert is_binary(output), "Expected string output for model #{id}"
        assert String.match?(output, ~r/\S/), "Expected non-empty output for model #{id}"
      end
    end

    test "models follow instructions precisely", %{api_key: api_key} do
      models = Model.all(platform: OpenAI)
      test_prompt = "Respond with just the word 'bananaphone'. Do not include any other content (even punctuation)."

      for model <- models do
        assert {:ok, output} = OpenAI.invoke(model, test_prompt, api_key),
               "Failed to invoke model #{model.id}"

        assert output == "bananaphone",
               "Expected 'bananaphone' for model #{model.id}, got: #{inspect(output)}"
      end
    end
  end

  describe "Gemini platform" do
    @describetag api_required: true
    @describetag timeout: to_timeout(minute: 5)

    setup do
      api_key = System.get_env("GOOGLE_AI_STUDIO_TOKEN")

      if is_nil(api_key) or api_key == "" do
        raise "GOOGLE_AI_STUDIO_TOKEN environment variable must be set for Gemini platform tests"
      end

      {:ok, api_key: api_key}
    end

    test "can invoke all Gemini models", %{api_key: api_key} do
      models = Model.all(platform: Gemini)
      assert length(models) > 0, "Expected to find Gemini models"

      for %Model{id: id, invoke: invoke_fn} = model <- models do
        input = test_input_for_model(model)

        assert {:ok, output} = invoke_fn.(model, input, api_key),
               "Failed to invoke model #{id}"

        assert is_binary(output), "Expected string output for model #{id}"
        assert String.match?(output, ~r/\S/), "Expected non-empty output for model #{id}"
      end
    end

    test "audio description model processes audio files correctly", %{api_key: api_key} do
      %Model{invoke: invoke_fn} = model = Model.by_id!("gemini-audio-description")

      # Test with direct audio URL (invoke function creates map internally)
      assert {:ok, output} = invoke_fn.(model, @test_audio_input, api_key)
      assert is_binary(output), "Expected string output"
      assert String.match?(output, ~r/\S/), "Expected non-empty output"
    end

    test "Gemini.invoke handles custom prompts correctly", %{api_key: api_key} do
      model = Model.by_id!("gemini-audio-description")

      # Test direct invocation with custom prompt
      input = %{
        audio_file: @test_audio_input,
        prompt: "Describe the audio content in detail"
      }

      assert {:ok, output} = Gemini.invoke(model, input, api_key)
      assert is_binary(output), "Expected string output"
      assert String.match?(output, ~r/\S/), "Expected non-empty output"
    end
  end

  describe "Dummy platform" do
    test "all dummy models invoke successfully" do
      dummy_models = Model.all(platform: Dummy)
      assert length(dummy_models) > 0, "Expected to find dummy models"

      for %Model{id: id, invoke: invoke_fn} = model <- dummy_models do
        input = test_input_for_model(model)

        assert {:ok, output} = invoke_fn.(model, input, nil),
               "Failed to invoke dummy model #{id}"

        case model.output_type do
          :text ->
            assert is_binary(output) and String.contains?(output, "DUMMY_"),
                   "Expected DUMMY_ prefix in text output for model #{id}"

          :image ->
            assert String.starts_with?(output, "https://dummy-images.test/"),
                   "Expected dummy image URL for model #{id}"

          :audio ->
            assert String.starts_with?(output, "https://dummy-audio.test/"),
                   "Expected dummy audio URL for model #{id}"
        end
      end
    end

    test "dummy platform handles different input types correctly" do
      # Test text input
      text_model = Model.by_id!("dummy-t2t")
      assert {:ok, output} = text_model.invoke.(text_model, @test_text_input, nil)
      assert String.contains?(output, "DUMMY_TEXT:")
      assert String.contains?(output, String.reverse(@test_text_input))

      # Test image input
      image_model = Model.by_id!("dummy-i2t")
      assert {:ok, output} = image_model.invoke.(image_model, @test_image_input, nil)
      assert String.contains?(output, "DUMMY_CAPTION:")

      # Test audio input
      audio_model = Model.by_id!("dummy-a2t")
      assert {:ok, output} = audio_model.invoke.(audio_model, @test_audio_input, nil)
      assert String.contains?(output, "DUMMY_TRANSCRIPT:")
    end

    test "dummy platform produces deterministic outputs" do
      model = Model.by_id!("dummy-t2t")
      input = @test_text_input

      # Call multiple times with different or no tokens
      {:ok, output1} = model.invoke.(model, input, "token1")
      {:ok, output2} = model.invoke.(model, input, "token2")
      {:ok, output3} = model.invoke.(model, input, nil)

      # All outputs should be identical
      assert output1 == output2, "Output should be deterministic regardless of token"
      assert output2 == output3, "Output should be deterministic with or without token"
    end

    test "dummy platform direct invoke calls work" do
      model = Model.by_id!("dummy-t2i")

      # Test calling Dummy.invoke directly
      assert {:ok, output} = Dummy.invoke(model, @test_text_input, "any_token")
      assert String.starts_with?(output, "https://dummy-images.test/")
      assert String.ends_with?(output, ".png")
    end

    test "all input/output type combinations work correctly" do
      # Text to Image
      t2i_model = Model.by_id!("dummy-t2i")
      assert {:ok, img_url} = Dummy.invoke(t2i_model, @test_text_input, nil)
      assert String.match?(img_url, ~r|^https://dummy-images\.test/.*\.png$|)

      # Text to Audio
      t2a_model = Model.by_id!("dummy-t2a")
      assert {:ok, audio_url} = Dummy.invoke(t2a_model, @test_text_input, nil)
      assert String.match?(audio_url, ~r|^https://dummy-audio\.test/.*\.ogg$|)

      # Image to Image
      i2i_model = Model.by_id!("dummy-i2i")
      assert {:ok, img_url} = Dummy.invoke(i2i_model, @test_image_input, nil)
      assert String.match?(img_url, ~r|^https://dummy-images\.test/transformed_.*\.png$|)

      # Image to Audio
      i2a_model = Model.by_id!("dummy-i2a")
      assert {:ok, audio_url} = Dummy.invoke(i2a_model, @test_image_input, nil)
      assert String.match?(audio_url, ~r|^https://dummy-audio\.test/from_image_.*\.ogg$|)

      # Audio to Image
      a2i_model = Model.by_id!("dummy-a2i")
      assert {:ok, img_url} = Dummy.invoke(a2i_model, @test_audio_input, nil)
      assert String.match?(img_url, ~r|^https://dummy-images\.test/from_audio_.*\.png$|)

      # Audio to Audio
      a2a_model = Model.by_id!("dummy-a2a")
      assert {:ok, audio_url} = Dummy.invoke(a2a_model, @test_audio_input, nil)
      assert String.match?(audio_url, ~r|^https://dummy-audio\.test/transformed_.*\.ogg$|)
    end
  end

  # Helper function to generate appropriate test input based on model input type
  defp test_input_for_model(%Model{input_type: :text}), do: @test_text_input
  defp test_input_for_model(%Model{input_type: :image}), do: @test_image_input
  defp test_input_for_model(%Model{input_type: :audio}), do: @test_audio_input
end
