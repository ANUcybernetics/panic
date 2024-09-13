defmodule Panic.Model do
  @moduledoc """
  Struct containing all the model info:

  - `id`: string used as a unique identifier for the model
  - `path`: path to the hosted model (exactly how that translates into the final URL depends on the platform)
  - `name`: human readable name for the model
  - `description`: brief description of the model (supports markdown)
  - `input_type`: input type (either `:text`, `:image` or `:audio`)
  - `output_type`: output type (either `:text`, `:image` or `:audio`)
  - `invoke`: is a function which takes `input` and `token` args and returns the output

  This information is stored in code (rather than in the database) because each
  model requires bespoke code to pull out the relevant return value (see the
  various versions of `create/3` in this module) and trying to keep that code in
  sync with this info in the database would be a nightmare.

  There are also a couple of helper functions for fetching/filtering models. So you can
  kinof squint at `Model` as a Repo of models, although they're just code (not in the db)
  because of the fact each model needs bespoke "turn result into something that works as an
  invocation output" code.
  """
  alias Panic.Platforms.OpenAI
  alias Panic.Platforms.Replicate

  @enforce_keys [:id, :path, :name, :platform, :input_type, :output_type, :invoke]
  defstruct [
    :id,
    :path,
    :name,
    :platform,
    :input_type,
    :output_type,
    :invoke,
    :description,
    :homepage
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          path: String.t(),
          name: String.t(),
          platform: Panic.Platforms.OpenAI | Panic.Platforms.Replicate,
          input_type: :text | :audio | :image,
          output_type: :text | :audio | :image,
          description: String.t() | nil,
          homepage: String.t() | nil,
          invoke: (String.t(), String.t() -> {:ok, String.t()} | {:error, String.t()})
        }

  def all() do
    [
      ## OpenAI
      %__MODULE__{
        id: "gpt-4",
        path: "gpt-4",
        name: "GPT-4",
        input_type: :text,
        output_type: :text,
        platform: OpenAI,
        invoke: fn input, token ->
          OpenAI.invoke("gpt-4", input, token)
        end
      },
      %__MODULE__{
        id: "gpt-4-turbo",
        path: "gpt-4-turbo",
        name: "GPT4 Turbo",
        input_type: :text,
        output_type: :text,
        platform: OpenAI,
        invoke: fn input, token ->
          OpenAI.invoke("gpt-4-turbo", input, token)
        end
      },
      %__MODULE__{
        id: "gpt-4o",
        path: "gpt-4",
        name: "GPT4o",
        input_type: :text,
        output_type: :text,
        platform: OpenAI,
        invoke: fn input, token ->
          OpenAI.invoke("gpt-4o", input, token)
        end
      },

      ## Replicate
      %__MODULE__{
        id: "2feet6inches/cog-prompt-parrot",
        platform: Replicate,
        path: "2feet6inches/cog-prompt-parrot",
        name: "Cog Prompt Parrot",
        input_type: :text,
        output_type: :text,
        invoke: fn input, token ->
          with {:ok, %{"output" => text}} <-
                 Replicate.invoke("2feet6inches/cog-prompt-parrot", %{prompt: input}, token) do
            {:ok, text |> String.split("\n") |> Enum.random()}
          end
        end
      },
      %__MODULE__{
        id: "rmokady/clip_prefix_caption",
        platform: Replicate,
        path: "rmokady/clip_prefix_caption",
        name: "Clip Prefix Caption",
        input_type: :image,
        output_type: :text,
        invoke: fn input, token ->
          with {:ok, %{"output" => text}} <-
                 Replicate.invoke("rmokady/clip_prefix_caption", %{image: input}, token) do
            {:ok, text}
          end
        end
      },
      %__MODULE__{
        id: "j-min/clip-caption-reward",
        platform: Replicate,
        path: "j-min/clip-caption-reward",
        name: "Clip Caption Reward",
        input_type: :image,
        output_type: :text,
        invoke: fn input, token ->
          with {:ok, %{"output" => text}} <-
                 Replicate.invoke("j-min/clip-caption-reward", %{image: input}, token) do
            {:ok, text}
          end
        end
      },
      %__MODULE__{
        id: "salesforce/blip-2",
        platform: Replicate,
        path: "salesforce/blip-2",
        name: "BLIP2",
        input_type: :image,
        output_type: :text,
        invoke: fn input, token ->
          with {:ok, %{"output" => text}} <-
                 Replicate.invoke(
                   "salesforce/blip-2",
                   %{image: input, caption: true},
                   token
                 ) do
            {:ok, text}
          end
        end
      },
      %__MODULE__{
        id: "stability-ai/stable-diffusion",
        platform: Replicate,
        path: "stability-ai/stable-diffusion",
        name: "Stable Diffusion",
        input_type: :text,
        output_type: :image,
        invoke: fn input, token ->
          input_params = %{
            prompt: input,
            num_inference_steps: 50,
            guidance_scale: 7.5,
            width: 1024,
            height: 576
          }

          with {:ok, %{"output" => [image_url]}} <-
                 Replicate.invoke("stability-ai/stable-diffusion", input_params, token) do
            {:ok, image_url}
          end
        end
      },
      %__MODULE__{
        id: "black-forest-labs/flux-schnell",
        platform: Replicate,
        path: "black-forest-labs/flux-schnell",
        name: "FLUX.1 [schnell]",
        input_type: :text,
        output_type: :image,
        invoke: fn input, token ->
          input_params = %{
            prompt: input,
            output_format: "jpg",
            aspect_ratio: "16:9",
            disable_safety_checker: true
          }

          with {:ok, %{"output" => image_url}} <-
                 Replicate.invoke("black-forest-labs/flux-schnell", input_params, token) do
            {:ok, image_url}
          end
        end
      },
      %__MODULE__{
        id: "stability-ai/sdxl",
        platform: Replicate,
        path: "stability-ai/sdxl",
        name: "Stable Diffusion XL",
        input_type: :text,
        output_type: :image,
        invoke: fn input, token ->
          input_params = %{
            prompt: input,
            num_inference_steps: 50,
            guidance_scale: 7.5,
            width: 1024,
            height: 576
          }

          with {:ok, %{"output" => [image_url]}} <-
                 Replicate.invoke("stability-ai/sdxl", input_params, token) do
            {:ok, image_url}
          end
        end
      },
      %__MODULE__{
        id: "yorickvp/llava-v1.6-34b",
        platform: Replicate,
        path: "yorickvp/llava-v1.6-34b",
        name: "LLaVA 34B text-to-image",
        input_type: :image,
        output_type: :text,
        invoke: fn input, token ->
          input_params = %{
            image: input,
            prompt:
              "Provide a detailed description of this image for captioning purposes, including descriptions both the foreground and background."
          }

          with {:ok, %{"output" => description_list}} <-
                 Replicate.invoke("yorickvp/llava-v1.6-34b", input_params, token) do
            {:ok, Enum.join(description_list)}
          end
        end
      },
      %__MODULE__{
        id: "meta/meta-llama-3-8b-instruct",
        platform: Replicate,
        path: "meta/meta-llama-3-8b-instruct",
        name: "LLaMa 8B Instruct",
        input_type: :text,
        output_type: :text,
        invoke: fn input, token ->
          with {:ok, %{"output" => output_list}} <-
                 Replicate.invoke("meta/meta-llama-3-8b-instruct", %{prompt: input}, token) do
            {:ok, Enum.join(output_list)}
          end
        end
      }
    ]
  end

  def all(filters) do
    all()
    |> Enum.filter(fn model ->
      filters
      |> Enum.map(fn {output, type} -> Map.fetch!(model, output) == type end)
      |> Enum.all?()
    end)
  end

  def by_id!(id) do
    case all(id: id) do
      [] -> raise "no model found with id #{id}"
      [model] -> model
      _ -> raise "multiple models found with id #{id}"
    end
  end

  def model_url(%__MODULE__{platform: OpenAI}) do
    "https://platform.openai.com/docs/models/overview"
  end

  def model_url(%__MODULE__{platform: Replicate, path: path}) do
    "https://replicate.com/#{path}"
  end
end
