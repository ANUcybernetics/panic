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

  - Vestaboard API calls
  - Replicate model invocations
  - OpenAI model invocations
  - Gemini model invocations
  - Archiver operations (file downloads, conversions, S3 uploads)
  """

  alias Panic.Engine.Archiver
  alias Panic.Platforms.Vestaboard

  @doc """
  Sets up all external API patches for testing.

  This should be called in test setup to ensure NetworkRunner
  doesn't make real external API calls during tests.
  """
  def setup do
    setup_vestaboard_patches()
    setup_model_patches()
    setup_archiver_patches()
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

  defp setup_vestaboard_patches do
    # Patch Vestaboard.send_text to avoid actual API calls
    Repatch.patch(Vestaboard, :send_text, fn _text, _token, _board_name ->
      {:ok, "mock-vestaboard-id-#{:rand.uniform(10_000)}"}
    end)

    # Patch token retrieval if needed
    Repatch.patch(Vestaboard, :token_for_board!, fn _board_name, _user ->
      "mock-vestaboard-token"
    end)
  end

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

  defp setup_archiver_patches do
    # These are already patched in test_helper.exs, but we include them
    # here for completeness and to avoid any potential issues

    Repatch.patch(Archiver, :download_file, fn _url ->
      {:ok, "/tmp/mock_file_#{:rand.uniform(10_000)}.webp"}
    end)

    Repatch.patch(Archiver, :convert_file, fn filename, _dest_rootname ->
      {:ok, filename}
    end)

    Repatch.patch(Archiver, :upload_to_s3, fn _file_path ->
      {:ok, "https://mock-s3-url.com/test-file-#{:rand.uniform(10_000)}.webp"}
    end)

    Repatch.patch(Archiver, :archive_invocation, fn _invocation, _next_invocation ->
      :ok
    end)

    # Patch NetworkRunner.archive_invocation_async to avoid Task.Supervisor calls in tests
    Repatch.patch(Panic.Engine.NetworkRunner, :archive_invocation_async, fn _invocation, _next_invocation ->
      :ok
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
