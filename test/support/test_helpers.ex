# ABOUTME: Test helper functions for checking API key availability and other test utilities
# ABOUTME: Used to conditionally skip tests that require real API credentials

defmodule Panic.TestHelpers do
  @moduledoc """
  Helper functions for tests, including API key availability checks.
  """

  @doc """
  Checks if real API keys are available in the test environment.
  Returns true only if both OpenAI and Replicate API keys are set via environment variables.
  """
  def real_api_keys_available? do
    openai_available?() && replicate_available?()
  end

  @doc """
  Checks if a real OpenAI API key is available.
  """
  def openai_available? do
    token = Application.get_env(:panic, :api_tokens)[:openai_token]
    token != nil && token != "test_openai_token" && String.starts_with?(token, "sk-")
  end

  @doc """
  Checks if a real Replicate API key is available.
  """
  def replicate_available? do
    token = Application.get_env(:panic, :api_tokens)[:replicate_token]
    token != nil && token != "test_replicate_token" && String.starts_with?(token, "r8_")
  end

  @doc """
  Skips the current test if real API keys are not available.
  Use this in individual tests that require real API credentials.
  """
  defmacro skip_without_api_keys do
    quote do
      if !Panic.TestHelpers.real_api_keys_available?() do
        import ExUnit.Assertions

        flunk(
          "Skipping test: Real API keys not available. Set OPENAI_API_KEY and REPLICATE_API_KEY environment variables to run this test."
        )
      end
    end
  end

  @doc """
  Returns a tag tuple that can be used with @tag to conditionally skip tests.
  """
  def api_test_tag do
    if real_api_keys_available?() do
      {}
    else
      {:skip, "Real API keys not available"}
    end
  end
end
