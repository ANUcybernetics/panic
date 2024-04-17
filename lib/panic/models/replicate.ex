defmodule Panic.Models.DalleMini do
  @behaviour Panic.Model

  @impl true
  def info do
    %Panic.Models.ModelInfo{
      id: "kuprel/min-dalle",
      platform: Panic.Platforms.Replicate,
      path: "kuprel/min-dalle",
      name: "DALL·E Mini",
      description: "",
      input_type: :text,
      output_type: :image
    }
  end

  def invoke(input) do
    with {:ok, %{"output" => [image_url]}} <-
           Panic.Platforms.Replicate.create_and_wait(
             model_id,
             %{text: input, grid_size: 1, progressive_outputs: 0},
             tokens
           ) do
      {:ok, image_url}
    end
  end
end

defmodule Panic.Models.PromptParrot do
  @behaviour Panic.Model

  @impl true
  def info do
    %Panic.Models.ModelInfo{
      id: "kyrick/prompt-parrot",
      platform: Panic.Platforms.Replicate,
      path: "kyrick/prompt-parrot",
      name: "Prompt Parrot",
      description: "",
      input_type: :text,
      output_type: :text
    }
  end

  def invoke(input) do
    with {:ok, %{"output" => text}} <-
           Panic.Platforms.Replicate.create_and_wait(model_id, %{prompt: prompt}, tokens) do
      {:ok,
       text |> String.split("\n------------------------------------------\n") |> Enum.random()}
    end
  end
end

defmodule Panic.Models.CogPromptParrot do
  @behaviour Panic.Model

  @impl true
  def info do
    %Panic.Models.ModelInfo{
      id: "2feet6inches/cog-prompt-parrot",
      platform: Panic.Platforms.Replicate,
      path: "2feet6inches/cog-prompt-parrot",
      name: "Cog Prompt Parrot",
      description: "",
      input_type: :text,
      output_type: :text
    }
  end

  def invoke(input) do
    with {:ok, %{"output" => text}} <-
           Panic.Platforms.Replicate.create_and_wait(model_id, %{prompt: prompt}, tokens) do
      {:ok, text |> String.split("\n") |> Enum.random()}
    end
  end
end

defmodule Panic.Models.ClipPrefixCaption do
  @behaviour Panic.Model

  @impl true
  def info do
    %Panic.Models.ModelInfo{
      id: "rmokady/clip_prefix_caption",
      platform: Panic.Platforms.Replicate,
      path: "rmokady/clip_prefix_caption",
      name: "Clip Prefix Caption",
      description: "",
      input_type: :image,
      output_type: :text
    }
  end

  def invoke(input) do
    with {:ok, %{"output" => text}} <-
           Panic.Platforms.Replicate.create_and_wait(model_id, %{image: image_url}, tokens) do
      {:ok, text}
    end
  end
end

defmodule Panic.Models.ClipCaptionReward do
  @behaviour Panic.Model

  @impl true
  def info do
    %Panic.Models.ModelInfo{
      id: "j-min/clip-caption-reward",
      platform: Panic.Platforms.Replicate,
      path: "j-min/clip-caption-reward",
      name: "Clip Caption Reward",
      description: "",
      input_type: :image,
      output_type: :text
    }
  end

  def invoke(input) do
    with {:ok, %{"output" => text}} <-
           Panic.Platforms.Replicate.create_and_wait(model_id, %{image: image_url}, tokens) do
      {:ok, text}
    end
  end
end

defmodule Panic.Models.BLIP2 do
  @behaviour Panic.Model

  @impl true
  def info do
    %Panic.Models.ModelInfo{
      id: "salesforce/blip-2",
      platform: Panic.Platforms.Replicate,
      path: "salesforce/blip-2",
      name: "BLIP2",
      description: "",
      input_type: :image,
      output_type: :text
    }
  end

  def invoke(input) do
    with {:ok, %{"output" => text}} <-
           Panic.Platforms.Replicate.create_and_wait(
             model_id,
             %{image: image_url, caption: true},
             tokens
           ) do
      {:ok, text}
    end
  end
end

defmodule Panic.Models.Vicuna13B do
  @behaviour Panic.Model

  @impl true
  def info do
    %Panic.Models.ModelInfo{
      id: "replicate/vicuna-13b",
      platform: Panic.Platforms.Replicate,
      path: "replicate/vicuna-13b",
      name: "vicuna 13B",
      description: "A large language model that's been fine-tuned on ChatGPT interactions",
      input_type: :text,
      output_type: :text
    }
  end

  def invoke(input) do
    with {:ok, %{"output" => output}} <-
           Panic.Platforms.Replicate.create_and_wait(model_id, %{prompt: prompt}, tokens) do
      {:ok, Enum.join(output)}
    end
  end
end

defmodule Panic.Models.StableDiffusion do
  @behaviour Panic.Model

  @impl true
  def info do
    %Panic.Models.ModelInfo{
      id: "stability-ai/stable-diffusion",
      platform: Panic.Platforms.Replicate,
      path: "stability-ai/stable-diffusion",
      # version: "f178fa7a1ae43a9a9af01b833b9d2ecf97b1bcb0acfd2dc5dd04895e042863f1",
      name: "Stable Diffusion",
      description: "",
      input_type: :text,
      output_type: :image
    }
  end

  def invoke(input) do
    input_params = %{
      prompt: input,
      num_inference_steps: 50,
      guidance_scale: 7.5,
      width: 1024,
      height: 576
    }

    with {:ok, %{"output" => [image_url]}} <-
           Panic.Platforms.Replicate.create_and_wait(model_id, input_params, tokens) do
      {:ok, image_url}
    end
  end
end

defmodule Panic.Models.SOCYSD do
  @behaviour Panic.Model

  @impl true
  def info do
    %Panic.Models.ModelInfo{
      id: "cloneofsimo/lora-socy",
      platform: Panic.Platforms.Replicate,
      path: "cloneofsimo/lora",
      name: "SOCY SD",
      description: "",
      input_type: :text,
      output_type: :image
    }
  end

  def invoke(input) do
    input_params = %{
      prompt: "#{prompt} in the style of <1>",
      width: 1024,
      height: 576,
      lora_urls:
        "https://replicate.delivery/pbxt/eIfm9M0WYEnnjUKQxyumkqiPtr6Pi0D8ee1bGufE74ieUpXIE/tmp5xnilpplHEADER20IMAGESzip.safetensors"
    }

    with {:ok, %{"output" => [image_url]}} <-
           Panic.Platforms.Replicate.create_and_wait(model_id, input_params, tokens) do
      {:ok, image_url}
    end
  end
end

defmodule Panic.Models.InstructPix2Pix do
  @behaviour Panic.Model

  @impl true
  def info do
    %Panic.Models.ModelInfo{
      id: "timothybrooks/instruct-pix2pix",
      platform: Panic.Platforms.Replicate,
      path: "timothybrooks/instruct-pix2pix",
      name: "Instruct pix2pix",
      description: "",
      input_type: :image,
      output_type: :image
    }
  end

  def invoke(input) do
    with {:ok, %{"output" => [output_image_url]}} <-
           Panic.Platforms.Replicate.create_and_wait(
             model_id,
             %{
               image: input_image_url,
               prompt: "change the environment, keep the human and technology"
             },
             tokens
           ) do
      {:ok, output_image_url}
    end
  end
end
