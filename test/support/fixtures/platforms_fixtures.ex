defmodule Panic.PlatformsFixtures do
  @moduledoc """
  This module defines test helpers for (faking) the different AI platform API endpoints
  """

  @doc """
  Provide a fake return value from the OpenAI endpoint.
  """
  def openai_create_text("davinci-instruct-beta", prompt) do
    "a nice story from GPT-3 based on the prompt #{prompt}"
  end

  def replicate_create_image_url("stability-ai/stable-diffusion", prompt) do
    "https://example.com/replicate-images/#{Slugify.slugify(prompt)}"
  end

  def replicate_create_text("j-min/clip-caption-reward", image_url) do
    "the image at #{image_url} is full of sheep and horses (probably)"
  end
end
