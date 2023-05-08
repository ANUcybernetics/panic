defmodule Panic.Platforms do
  @moduledoc """
  The Platforms context.

  The platforms & model configuration isn't in the DB, so this context is a bit
  different from the standard Phoenix one.
  """

  alias Panic.Platforms.Model

  @models [
    %Model{
      id: "replicate:kuprel/min-dalle",
      path: "kuprel/min-dalle",
      name: "DALL·E Mini",
      description: "",
      input: :text,
      output: :image,
      platform: Panic.Platforms.Replicate
    },
    %Model{
      id: "replicate:kyrick/prompt-parrot",
      path: "kyrick/prompt-parrot",
      name: "Prompt Parrot",
      description: "",
      input: :text,
      output: :text,
      platform: Panic.Platforms.Replicate
    },
    %Model{
      id: "replicate:2feet6inches/cog-prompt-parrot",
      path: "2feet6inches/cog-prompt-parrot",
      name: "Cog Prompt Parrot",
      description: "",
      input: :text,
      output: :text,
      platform: Panic.Platforms.Replicate
    },
    %Model{
      id: "replicate:rmokady/clip_prefix_caption",
      path: "rmokady/clip_prefix_caption",
      name: "Clip Prefix Caption",
      description: "",
      input: :image,
      output: :text,
      platform: Panic.Platforms.Replicate
    },
    %Model{
      id: "replicate:j-min/clip-caption-reward",
      path: "j-min/clip-caption-reward",
      name: "Clip Caption Reward",
      description: "",
      input: :image,
      output: :text,
      platform: Panic.Platforms.Replicate
    },
    %Model{
      id: "replicate:salesforce/blip-2",
      path: "salesforce/blip-2",
      name: "BLIP2",
      description: "",
      input: :image,
      output: :text,
      platform: Panic.Platforms.Replicate
    },
    %Model{
      id: "replicate:replicate/vicuna-13b",
      path: "replicate/vicuna-13b",
      name: "vicuna 13B",
      description: "A large language model that's been fine-tuned on ChatGPT interactions",
      input: :text,
      output: :text,
      platform: Panic.Platforms.Replicate
    },
    %Model{
      id: "replicate:stability-ai/stable-diffusion",
      path: "stability-ai/stable-diffusion",
      version: "f178fa7a1ae43a9a9af01b833b9d2ecf97b1bcb0acfd2dc5dd04895e042863f1",
      name: "Stable Diffusion",
      description: "",
      input: :text,
      output: :image,
      platform: Panic.Platforms.Replicate
    },
    %Model{
      id: "replicate:cloneofsimo/lora-socy",
      path: "cloneofsimo/lora",
      name: "SOCY SD",
      description: "",
      input: :text,
      output: :image,
      platform: Panic.Platforms.Replicate
    },
    %Model{
      id: "replicate:timothybrooks/instruct-pix2pix",
      path: "timothybrooks/instruct-pix2pix",
      name: "Instruct pix2pix",
      description: "",
      input: :image,
      output: :image,
      platform: Panic.Platforms.Replicate
    },
    %Model{
      id: "openai:text-davinci-003",
      path: "text-davinci-003",
      name: "GPT-3 Davinci",
      description: "",
      input: :text,
      output: :text,
      platform: Panic.Platforms.OpenAI
    },
    %Model{
      id: "openai:text-ada-001",
      path: "text-ada-001",
      name: "GPT-3 Ada",
      description: "",
      input: :text,
      output: :text,
      platform: Panic.Platforms.OpenAI
    },
    %Model{
      id: "openai:davinci-instruct-beta",
      path: "davinci-instruct-beta",
      name: "GPT-3 Davinci Instruct",
      description: "",
      input: :text,
      output: :text,
      platform: Panic.Platforms.OpenAI
    },
    %Model{
      id: "openai:gpt-3.5-turbo",
      path: "gpt-3.5-turbo",
      name: "ChatGPT",
      description: "",
      input: :text,
      output: :text,
      platform: Panic.Platforms.OpenAI
    }
  ]

  def models do
    @models
  end

  def model_ids do
    Enum.map(@models, & &1.id)
  end

  def model_info(model_id) do
    Enum.find(@models, &(&1.id == model_id))
  end

  def model_input_type(model_id) do
    model_id |> model_info() |> Map.get(:input)
  end

  def model_output_type(model_id) do
    model_id |> model_info() |> Map.get(:output)
  end

  def api_call(model_id, input, tokens) do
    platform = model_id |> model_info() |> Map.get(:platform)
    platform.create(model_id, input, tokens)
  end
end
