defmodule Panic.Models.DalleMini do
  @behaviour Panic.Model
  alias Panic.Platforms.Replicate

  @info %Panic.Models.ModelInfo{
    id: "kuprel/min-dalle",
    platform: Replicate,
    path: "kuprel/min-dalle",
    name: "DALL·E Mini",
    description: "",
    input_type: :text,
    output_type: :image
  }

  @impl true
  def info, do: @info

  @impl true
  def info(field), do: Map.fetch!(@info, field)

  @impl true
  def invoke(input) do
    model_id = @info.id

    with {:ok, %{"output" => [image_url]}} <-
           Replicate.create_and_wait(
             model_id,
             %{text: input, grid_size: 1, progressive_outputs: 0}
           ) do
      {:ok, image_url}
    end
  end
end

defmodule Panic.Models.PromptParrot do
  @behaviour Panic.Model
  alias Panic.Platforms.Replicate

  @info %Panic.Models.ModelInfo{
    id: "kyrick/prompt-parrot",
    platform: Replicate,
    path: "kyrick/prompt-parrot",
    name: "Prompt Parrot",
    description: "",
    input_type: :text,
    output_type: :text
  }

  @impl true
  def info, do: @info

  @impl true
  def info(field), do: Map.fetch!(@info, field)

  @impl true
  def invoke(input) do
    model_id = @info.id

    with {:ok, %{"output" => text}} <-
           Replicate.create_and_wait(model_id, %{prompt: input}) do
      {:ok,
       text |> String.split("\n------------------------------------------\n") |> Enum.random()}
    end
  end
end

defmodule Panic.Models.CogPromptParrot do
  @behaviour Panic.Model
  alias Panic.Platforms.Replicate

  @info %Panic.Models.ModelInfo{
    id: "2feet6inches/cog-prompt-parrot",
    platform: Replicate,
    path: "2feet6inches/cog-prompt-parrot",
    name: "Cog Prompt Parrot",
    description: "",
    input_type: :text,
    output_type: :text
  }

  @impl true
  def info, do: @info

  @impl true
  def info(field), do: Map.fetch!(@info, field)

  @impl true
  def invoke(input) do
    model_id = @info.id

    with {:ok, %{"output" => text}} <-
           Replicate.create_and_wait(model_id, %{prompt: input}) do
      {:ok, text |> String.split("\n") |> Enum.random()}
    end
  end
end

defmodule Panic.Models.ClipPrefixCaption do
  @behaviour Panic.Model
  alias Panic.Platforms.Replicate

  @info %Panic.Models.ModelInfo{
    id: "rmokady/clip_prefix_caption",
    platform: Replicate,
    path: "rmokady/clip_prefix_caption",
    name: "Clip Prefix Caption",
    description: "",
    input_type: :image,
    output_type: :text
  }

  @impl true
  def info, do: @info

  @impl true
  def info(field), do: Map.fetch!(@info, field)

  @impl true
  def invoke(input) do
    model_id = @info.id

    with {:ok, %{"output" => text}} <-
           Replicate.create_and_wait(model_id, %{image: input}) do
      {:ok, text}
    end
  end
end

defmodule Panic.Models.ClipCaptionReward do
  @behaviour Panic.Model
  alias Panic.Platforms.Replicate

  @info %Panic.Models.ModelInfo{
    id: "j-min/clip-caption-reward",
    platform: Replicate,
    path: "j-min/clip-caption-reward",
    name: "Clip Caption Reward",
    description: "",
    input_type: :image,
    output_type: :text
  }

  @impl true
  def info, do: @info

  @impl true
  def info(field), do: Map.fetch!(@info, field)

  @impl true
  def invoke(input) do
    model_id = @info.id

    with {:ok, %{"output" => text}} <-
           Replicate.create_and_wait(model_id, %{image: input}) do
      {:ok, text}
    end
  end
end

defmodule Panic.Models.BLIP2 do
  @behaviour Panic.Model
  alias Panic.Platforms.Replicate

  @info %Panic.Models.ModelInfo{
    id: "salesforce/blip-2",
    platform: Replicate,
    path: "salesforce/blip-2",
    name: "BLIP2",
    description: "",
    input_type: :image,
    output_type: :text
  }

  @impl true
  def info, do: @info

  @impl true
  def info(field), do: Map.fetch!(@info, field)

  @impl true
  def invoke(input) do
    model_id = @info.id

    with {:ok, %{"output" => text}} <-
           Replicate.create_and_wait(
             model_id,
             %{image: input, caption: true}
           ) do
      {:ok, text}
    end
  end
end

defmodule Panic.Models.Vicuna13B do
  @behaviour Panic.Model
  alias Panic.Platforms.Replicate

  @info %Panic.Models.ModelInfo{
    id: "replicate/vicuna-13b",
    platform: Replicate,
    path: "replicate/vicuna-13b",
    name: "vicuna 13B",
    description: "A large language model that's been fine-tuned on ChatGPT interactions",
    input_type: :text,
    output_type: :text
  }

  @impl true
  def info, do: @info

  @impl true
  def info(field), do: Map.fetch!(@info, field)

  @impl true
  def invoke(input) do
    model_id = @info.id

    with {:ok, %{"output" => output}} <-
           Replicate.create_and_wait(model_id, %{prompt: input}) do
      {:ok, Enum.join(output)}
    end
  end
end

defmodule Panic.Models.StableDiffusion do
  @behaviour Panic.Model
  alias Panic.Platforms.Replicate

  @info %Panic.Models.ModelInfo{
    id: "stability-ai/stable-diffusion",
    platform: Replicate,
    path: "stability-ai/stable-diffusion",
    name: "Stable Diffusion",
    description: "",
    input_type: :text,
    output_type: :image
  }

  @impl true
  def info, do: @info

  @impl true
  def info(field), do: Map.fetch!(@info, field)

  @impl true
  def invoke(input) do
    input_params = %{
      prompt: input,
      num_inference_steps: 50,
      guidance_scale: 7.5,
      width: 1024,
      height: 576
    }

    model_id = @info.id

    with {:ok, %{"output" => [image_url]}} <-
           Replicate.create_and_wait(model_id, input_params) do
      {:ok, image_url}
    end
  end
end

defmodule Panic.Models.SOCYSD do
  @behaviour Panic.Model
  alias Panic.Platforms.Replicate

  @info %Panic.Models.ModelInfo{
    id: "cloneofsimo/lora-socy",
    platform: Replicate,
    path: "cloneofsimo/lora",
    name: "SOCY SD",
    description: "",
    input_type: :text,
    output_type: :image
  }

  @impl true
  def info, do: @info

  @impl true
  def info(field), do: Map.fetch!(@info, field)

  @impl true
  def invoke(input) do
    input_params = %{
      prompt: "#{input} in the style of <1>",
      width: 1024,
      height: 576,
      lora_urls:
        "https://replicate.delivery/pbxt/eIfm9M0WYEnnjUKQxyumkqiPtr6Pi0D8ee1bGufE74ieUpXIE/tmp5xnilpplHEADER20IMAGESzip.safetensors"
    }

    model_id = @info.id

    with {:ok, %{"output" => [image_url]}} <-
           Replicate.create_and_wait(model_id, input_params) do
      {:ok, image_url}
    end
  end
end

defmodule Panic.Models.InstructPix2Pix do
  @behaviour Panic.Model
  alias Panic.Platforms.Replicate

  @info %Panic.Models.ModelInfo{
    id: "timothybrooks/instruct-pix2pix",
    platform: Replicate,
    path: "timothybrooks/instruct-pix2pix",
    name: "Instruct pix2pix",
    description: "",
    input_type: :image,
    output_type: :image
  }

  @impl true
  def info, do: @info

  @impl true
  def info(field), do: Map.fetch!(@info, field)

  @impl true
  def invoke(input) do
    model_id = @info.id

    with {:ok, %{"output" => [output_image_url]}} <-
           Replicate.create_and_wait(
             model_id,
             %{
               image: input,
               prompt: "change the environment, keep the human and technology"
             }
           ) do
      {:ok, output_image_url}
    end
  end
end
