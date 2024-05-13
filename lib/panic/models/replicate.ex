defmodule Panic.Models.PromptParrot do
  @behaviour Panic.Model
  alias Panic.Platforms.Replicate

  @impl true
  def info do
    %Panic.Models.ModelInfo{
      id: "kyrick/prompt-parrot",
      platform: Replicate,
      path: "kyrick/prompt-parrot",
      name: "Prompt Parrot",
      description: "",
      input_type: :text,
      output_type: :text
    }
  end

  @impl true
  def fetch!(field) do
    info() |> Map.fetch!(field)
  end

  @impl true
  def invoke(input) do
    with {:ok, %{"output" => text}} <-
           Replicate.create_and_wait(__MODULE__, %{prompt: input}) do
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
    with {:ok, %{"output" => text}} <-
           Replicate.create_and_wait(__MODULE__, %{prompt: input}) do
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
    with {:ok, %{"output" => text}} <-
           Replicate.create_and_wait(__MODULE__, %{image: input}) do
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
    with {:ok, %{"output" => text}} <-
           Replicate.create_and_wait(__MODULE__, %{image: input}) do
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
    with {:ok, %{"output" => text}} <-
           Replicate.create_and_wait(__MODULE__,
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
    with {:ok, %{"output" => output}} <-
           Replicate.create_and_wait(__MODULE__, %{prompt: input}) do
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

    with {:ok, %{"output" => [image_url]}} <-
           Replicate.create_and_wait(__MODULE__, input_params) do
      {:ok, image_url}
    end
  end
end

defmodule Panic.Models.SDXL do
  @behaviour Panic.Model
  alias Panic.Platforms.Replicate

  @info %Panic.Models.ModelInfo{
    id: "stability-ai/sdxl",
    platform: Replicate,
    path: "stability-ai/sdxl",
    name: "Stable Diffusion XL",
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

    with {:ok, %{"output" => [image_url]}} <-
           Replicate.create_and_wait(__MODULE__, input_params) do
      {:ok, image_url}
    end
  end
end

defmodule Panic.Models.LLaVA do
  @behaviour Panic.Model
  alias Panic.Platforms.Replicate

  @info %Panic.Models.ModelInfo{
    id: "yorickvp/llava-v1.6-34b",
    platform: Replicate,
    path: "yorickvp/llava-v1.6-34b",
    name: "LLaVA 34B text-to-image",
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
    input_params = %{
      image: input,
      prompt: "Provide a detailed description of this image for captioning purposes, including descriptions both the foreground and background."
    }

    with {:ok, %{"output" => description_list}} <-
           Replicate.create_and_wait(__MODULE__, input_params) do
      {:ok, Enum.join(description_list)}
    end
  end
end
