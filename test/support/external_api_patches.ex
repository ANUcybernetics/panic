defmodule Panic.ExternalAPIPatches do
  @moduledoc """
  Centralized Repatch definitions for external API calls during testing.

  This module patches external API calls that NetworkRunner makes during
  invocation processing to avoid actual network requests during tests.

  ## Usage

      setup do
        Panic.ExternalAPIPatches.setup()
        on_exit(&Panic.ExternalAPIPatches.teardown/0)
      end

  ## Patched APIs

  - Replicate model invocations
  - OpenAI model invocations
  - Gemini model invocations

  Note: Vestaboard API calls are disabled via config in test.exs
  Note: Archiver operations are patched separately in ArchiverPatches
  """

  @doc """
  Sets up all external API patches for testing.

  This should be called in test setup to ensure NetworkRunner
  doesn't make real external API calls during tests.
  """
  def setup do
    setup_model_patches()
    # Archiver patches are already applied in test_helper.exs via ArchiverPatches module
    # Vestaboard is disabled via config :disable_vestaboard in test.exs
    :ok
  end

  @doc """
  Tears down all external API patches.

  This should be called in test cleanup to restore original behavior.
  """
  def teardown do
    # Repatch automatically handles cleanup when patches go out of scope
    # This is mainly for explicit cleanup if needed
    :ok
  end

  # Private functions

  defp setup_model_patches do
    # Patch Replicate API calls
    Repatch.patch(Panic.Platforms.Replicate, :invoke, fn _model, _input, _token ->
      {:ok, generate_mock_output()}
    end)

    # Patch OpenAI API calls
    Repatch.patch(Panic.Platforms.OpenAI, :invoke, fn _model, _input, _token ->
      {:ok, generate_mock_output()}
    end)

    # Patch Gemini API calls
    Repatch.patch(Panic.Platforms.Gemini, :invoke, fn _model, _input, _token ->
      {:ok, generate_mock_output()}
    end)
  end

  defp generate_mock_output do
    # Generate different types of mock output based on randomness
    case :rand.uniform(4) do
      1 -> "Mock text output from AI model"
      2 -> "https://mock-image-url.com/generated-#{:rand.uniform(10_000)}.jpg"
      3 -> "https://mock-audio-url.com/generated-#{:rand.uniform(10_000)}.wav"
      4 -> "Mock response: #{Enum.random(["Success!", "Complete!", "Generated!", "Processed!"])}"
    end
  end
end
