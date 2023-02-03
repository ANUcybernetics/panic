defmodule Panic.Platforms do
  @moduledoc """
  The Platforms context.

  The platforms & model configuration isn't in the DB, so this context is a bit
  different from the standard Phoenix one.
  """

  def list_platforms do
    [Panic.Platforms.OpenAI, Panic.Platforms.Replicate]
  end

  @doc """
  List model info tuples

  Each one has the form `{model, input_type, output_type}`.

  `model` is a binary matching the pattern `platform:user/model-name`

  The actual API implementation details (e.g munging input/output parameters if
  necessary) are in the respective `create(model, input, user)` function in the
  respective Platform module.

  """
  def list_model_info do
    [
      # {"huggingface:facebook/fastspeech2-en-ljspeech", :text, :audio},
      # {"huggingface:facebook/wav2vec2-base-960h", :audio, :text},
      {"openai:text-davinci-003", :text, :text},
      {"openai:text-ada-001", :text, :text},
      {"openai:davinci-instruct-beta", :text, :text},
      {"replicate:charlesfrye/text-recognizer-gpu", :image, :text},
      {"replicate:kuprel/min-dalle", :text, :image},
      {"replicate:kyrick/prompt-parrot", :text, :text},
      {"replicate:2feet6inches/cog-prompt-parrot", :text, :text},
      {"replicate:methexis-inc/img2prompt", :image, :text},
      {"replicate:rmokady/clip_prefix_caption", :image, :text},
      {"replicate:j-min/clip-caption-reward", :image, :text},
      {"replicate:stability-ai/stable-diffusion", :text, :image},
      {"replicate:prompthero/openjourney", :text, :image}
    ]
  end

  def api_call(model, input, user) do
    [platform, model_name] = String.split(model, ":")

    case platform do
      "replicate" -> Panic.Platforms.Replicate.create(model_name, input, user)
      "openai" -> Panic.Platforms.OpenAI.create(model_name, input, user)
    end
  end
end
