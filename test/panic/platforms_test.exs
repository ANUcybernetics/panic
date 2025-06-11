defmodule Panic.PlatformsTest do
  @moduledoc """
  Tests for platform-specific model invocation functions.

  Each platform is tested by calling its invoke function directly,
  not through the Invocation resource's invoke action.
  """

  use Panic.DataCase

  alias Panic.Model
  alias Panic.Platforms.Dummy
  alias Panic.Platforms.OpenAI
  alias Panic.Platforms.Replicate

  # Module-level test inputs for different input types
  @test_text_input "a shiny red apple"
  @test_image_input "https://fly.storage.tigris.dev/panic-invocation-outputs/nsfw-placeholder.webp"
  @test_audio_input "https://fly.storage.tigris.dev/panic-invocation-outputs/test-audio.ogg"

  describe "Replicate platform" do
    @describetag api_required: true
    @describetag timeout: to_timeout(minute: 10)

    test "can list latest model version for all models" do
      user = Panic.Fixtures.user_with_real_tokens()
      models = Model.all(platform: Replicate)

      for model <- models do
        assert {:ok, version} = Replicate.get_latest_model_version(model, user.replicate_token)
        assert String.match?(version, ~r/^[a-f0-9]{64}$/)
      end
    end

    test "can generate a stable diffusion image" do
      user = Panic.Fixtures.user_with_real_tokens()
      %Model{invoke: invoke_fn} = model = Model.by_id!("flux-schnell")

      {:ok, img_url} =
        invoke_fn.(model, @test_text_input, user.replicate_token)

      assert String.match?(img_url, ~r|^https://.*$|)
    end

    test "BLIP2 captioner is sufficiently expressive" do
      user = Panic.Fixtures.user_with_real_tokens()
      %Model{invoke: invoke_fn} = model = Model.by_id!("blip-2")
      # TODO the rate limit here is pretty low, so maybe switch to a static image somewhere?
      input_img = "https://picsum.photos/400/225/"

      {:ok, caption} =
        invoke_fn.(model, input_img, user.replicate_token)

      # not a 100% reliable test, but we're going for descriptive captions here
      assert String.length(caption) > 10
    end

    test "can successfully invoke a specific model" do
      user = Panic.Fixtures.user_with_real_tokens()
      %Model{invoke: invoke_fn} = model = Model.by_id!("florence-2-large")
      input = test_input_for_model(model)

      assert {:ok, output} = invoke_fn.(model, input, user.replicate_token)
      assert String.match?(output, ~r/\S/)
    end

    @tag skip: true
    @tag api_required: true
    test "can successfully invoke all Replicate models" do
      user = Panic.Fixtures.user_with_real_tokens()
      models = Model.all(platform: Replicate)

      tasks =
        for %Model{id: id, invoke: invoke_fn} = model <- models do
          Task.async(fn ->
            input = test_input_for_model(model)
            result = invoke_fn.(model, input, user.replicate_token)

            case result do
              {:ok, output} ->
                IO.puts("#{id}: Input: #{inspect(input)}, Output: #{inspect(output)}")

              _ ->
                :pass
            end

            {id, result}
          end)
        end

      results = Task.await_many(tasks, :infinity)

      failed_models =
        results
        |> Enum.filter(fn {_, result} ->
          case result do
            {:error, _} -> true
            _ -> false
          end
        end)
        |> Enum.map(fn {id, _} -> id end)

      if length(failed_models) > 0 do
        IO.puts("Failed models: #{Enum.join(failed_models, ", ")}")
      end

      for {_, result} <- results do
        case result do
          {:ok, output} ->
            assert String.match?(output, ~r/\S/)

          {:error, _} ->
            flunk("Some models failed to invoke")
        end
      end
    end
  end

  describe "OpenAI platform" do
    @describetag api_required: true

    test "generates the right answer for all models" do
      # models for which we have canned responses
      user = Panic.Fixtures.user_with_real_tokens()
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

    test "can invoke OpenAI models with standard text input" do
      user = Panic.Fixtures.user_with_real_tokens()
      models = Model.all(platform: OpenAI)

      for %Model{invoke: invoke_fn} = model <- models do
        input = test_input_for_model(model)
        assert {:ok, output} = invoke_fn.(model, input, user.openai_token)
        assert String.match?(output, ~r/\S/)
      end
    end
  end

  describe "Gemini platform" do
    @describetag api_required: true

    test "can successfully invoke the audio description model" do
      %Model{invoke: invoke_fn} = model = Model.by_id!("gemini-audio-description")
      input = test_input_for_model(model)

      assert {:ok, output} = invoke_fn.(model, input, System.get_env("GOOGLE_AI_STUDIO_TOKEN"))
      assert String.match?(output, ~r/\S/)
    end

    test "audio description model handles audio file input correctly" do
      %Model{invoke: invoke_fn} = model = Model.by_id!("gemini-audio-description")

      # Test with direct audio URL (invoke function creates map internally)
      assert {:ok, output} = invoke_fn.(model, @test_audio_input, System.get_env("GOOGLE_AI_STUDIO_TOKEN"))
      assert String.match?(output, ~r/\S/)
    end
  end

  describe "Dummy platform" do
    test "all dummy models invoke successfully" do
      dummy_models = Model.all(platform: Dummy)

      for %Model{invoke: invoke_fn} = model <- dummy_models do
        input = test_input_for_model(model)

        assert {:ok, output} = invoke_fn.(model, input, nil)

        case model.output_type do
          :text -> assert is_binary(output) and String.contains?(output, "DUMMY_")
          :image -> assert String.starts_with?(output, "https://dummy-images.test/")
          :audio -> assert String.starts_with?(output, "https://dummy-audio.test/")
        end
      end
    end

    test "dummy platform handles different input types correctly" do
      # Test text input
      text_model = Model.by_id!("dummy-t2t")
      assert {:ok, output} = text_model.invoke.(text_model, @test_text_input, nil)
      assert String.contains?(output, "DUMMY_TEXT:")

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

      # Call multiple times
      {:ok, output1} = model.invoke.(model, input, "token1")
      {:ok, output2} = model.invoke.(model, input, "token2")
      {:ok, output3} = model.invoke.(model, input, nil)

      # All outputs should be identical
      assert output1 == output2
      assert output2 == output3
    end

    test "dummy platform direct invoke calls work" do
      model = Model.by_id!("dummy-t2i")

      # Test calling Dummy.invoke directly
      assert {:ok, output} = Dummy.invoke(model, @test_text_input, "any_token")
      assert String.starts_with?(output, "https://dummy-images.test/")
      assert String.ends_with?(output, ".png")
    end
  end

  # Helper function to generate appropriate test input based on model input type
  defp test_input_for_model(%Model{input_type: :text}), do: @test_text_input
  defp test_input_for_model(%Model{input_type: :image}), do: @test_image_input
  defp test_input_for_model(%Model{input_type: :audio}), do: @test_audio_input
end
