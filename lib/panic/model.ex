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
  @behaviour Access

  alias Panic.Platforms.OpenAI
  alias Panic.Platforms.Replicate
  alias Panic.Platforms.Vestaboard

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

  @impl Access
  def fetch(model, key), do: Map.fetch(model, key)

  @impl Access
  def get_and_update(model, key, fun) do
    Map.get_and_update(model, key, fun)
  end

  @impl Access
  def pop(model, key) do
    {value, new_model} = Map.pop(model, key)
    {value, struct(__MODULE__, Map.to_list(new_model))}
  end

  def all do
    [
      ## OpenAI
      %__MODULE__{
        id: "gpt-4o",
        path: "gpt-4o",
        name: "GPT-4o",
        input_type: :text,
        output_type: :text,
        platform: OpenAI,
        invoke: fn model, input, token ->
          OpenAI.invoke(model, input, token)
        end
      },
      %__MODULE__{
        id: "gpt-4o-mini",
        path: "gpt-4o-mini",
        name: "GPT-4o mini",
        input_type: :text,
        output_type: :text,
        platform: OpenAI,
        invoke: fn model, input, token ->
          OpenAI.invoke(model, input, token)
        end
      },

      ## Replicate
      %__MODULE__{
        id: "bunny-phi-2-siglip",
        platform: Replicate,
        path: "adirik/bunny-phi-2-siglip",
        name: "Bunny Phi 2 SigLIP",
        input_type: :image,
        output_type: :text,
        invoke: fn model, input, token ->
          with {:ok, %{"output" => text}} <-
                 Replicate.invoke(
                   model,
                   %{
                     image: input,
                     prompt:
                       "Give an interesting, concise caption for this image. Describe foreground and background elements.",
                     max_new_tokens: 50
                   },
                   token
                 ) do
            {:ok, text}
          end
        end
      },
      %__MODULE__{
        id: "joy-caption",
        platform: Replicate,
        path: "pipi32167/joy-caption",
        name: "Joy Caption",
        input_type: :image,
        output_type: :text,
        invoke: fn model, input, token ->
          with {:ok, %{"output" => text}} <-
                 Replicate.invoke(model, %{image: input, prompt: "A descriptive caption for this image:"}, token) do
            {:ok, text}
          end
        end
      },
      %__MODULE__{
        id: "blip-2",
        platform: Replicate,
        path: "salesforce/blip-2",
        name: "BLIP2",
        input_type: :image,
        output_type: :text,
        invoke: fn model, input, token ->
          with {:ok, %{"output" => text}} <-
                 Replicate.invoke(
                   model,
                   %{
                     image: input,
                     question:
                       "Describe this picture in detail, using lots of descriptive adjectives. Include information about both foreground and background elements."
                   },
                   token
                 ) do
            {:ok, text}
          end
        end
      },
      %__MODULE__{
        id: "stable-diffusion-test",
        description: "SD, but really small/cheap/fast - useful for testing",
        platform: Replicate,
        path: "stability-ai/stable-diffusion",
        name: "Stable Diffusion Test",
        input_type: :text,
        output_type: :image,
        invoke: fn model, input, token ->
          input_params = %{
            prompt: input,
            num_inference_steps: 1,
            guidance_scale: 5.0,
            width: 128,
            height: 128
          }

          with {:ok, %{"output" => [image_url]}} <-
                 Replicate.invoke(model, input_params, token) do
            {:ok, image_url}
          end
        end
      },
      %__MODULE__{
        id: "stable-diffusion",
        platform: Replicate,
        path: "stability-ai/stable-diffusion",
        name: "Stable Diffusion",
        input_type: :text,
        output_type: :image,
        invoke: fn model, input, token ->
          input_params = %{
            prompt: input,
            num_inference_steps: 50,
            guidance_scale: 7.5,
            width: 1024,
            height: 576
          }

          with {:ok, %{"output" => [image_url]}} <-
                 Replicate.invoke(model, input_params, token) do
            {:ok, image_url}
          end
        end
      },
      %__MODULE__{
        id: "flux-schnell",
        platform: Replicate,
        path: "black-forest-labs/flux-schnell",
        name: "FLUX.1 [schnell]",
        input_type: :text,
        output_type: :image,
        invoke: fn model, input, token ->
          input_params = %{
            prompt: input,
            output_format: "jpg",
            aspect_ratio: "16:9",
            disable_safety_checker: true
          }

          with {:ok, %{"output" => [image_url]}} <-
                 Replicate.invoke(model, input_params, token) do
            {:ok, image_url}
          end
        end
      },
      %__MODULE__{
        id: "sdxl",
        platform: Replicate,
        path: "stability-ai/sdxl",
        name: "Stable Diffusion XL",
        input_type: :text,
        output_type: :image,
        invoke: fn model, input, token ->
          input_params = %{
            prompt: input,
            num_inference_steps: 50,
            guidance_scale: 7.5,
            width: 1024,
            height: 576
          }

          with {:ok, %{"output" => [image_url]}} <-
                 Replicate.invoke(model, input_params, token) do
            {:ok, image_url}
          end
        end
      },
      # %__MODULE__{
      #   id: "llava-v1.6-34b",
      #   platform: Replicate,
      #   path: "yorickvp/llava-v1.6-34b",
      #   name: "LLaVA 34B text-to-image",
      #   input_type: :image,
      #   output_type: :text,
      #   invoke: fn model, input, token ->
      #     input_params = %{
      #       image: input,
      #       prompt:
      #         "Provide a detailed description of this image for captioning purposes, including descriptions both the foreground and background."
      #     }

      #     with {:ok, %{"output" => description_list}} <-
      #            Replicate.invoke(model, input_params, token) do
      #       {:ok, Enum.join(description_list)}
      #     end
      #   end
      # },
      %__MODULE__{
        id: "meta-llama-3-8b-instruct",
        platform: Replicate,
        path: "meta/meta-llama-3-8b-instruct",
        name: "LLaMa 8B Instruct",
        input_type: :text,
        output_type: :text,
        invoke: fn model, input, token ->
          with {:ok, %{"output" => output_list}} <-
                 Replicate.invoke(model, %{prompt: input}, token) do
            {:ok, Enum.join(output_list)}
          end
        end
      },

      ## Vestaboards

      %__MODULE__{
        id: "vestaboard-panic-1",
        platform: Vestaboard,
        path: "panic_1",
        name: "Vestaboard Panic 1",
        input_type: :text,
        output_type: :text,
        invoke: fn model, input, token ->
          Vestaboard.send_text(model, input, token)
        end
      },
      %__MODULE__{
        id: "vestaboard-panic-2",
        platform: Vestaboard,
        path: "panic_2",
        name: "Vestaboard Panic 2",
        input_type: :text,
        output_type: :text,
        invoke: fn model, input, token ->
          Vestaboard.send_text(model, input, token)
        end
      },
      %__MODULE__{
        id: "vestaboard-panic-3",
        platform: Vestaboard,
        path: "panic_3",
        name: "Vestaboard Panic 3",
        input_type: :text,
        output_type: :text,
        invoke: fn model, input, token ->
          Vestaboard.send_text(model, input, token)
        end
      },
      %__MODULE__{
        id: "vestaboard-panic-4",
        platform: Vestaboard,
        path: "panic_4",
        name: "Vestaboard Panic 4",
        input_type: :text,
        output_type: :text,
        invoke: fn model, input, token ->
          Vestaboard.send_text(model, input, token)
        end
      }
    ]
  end

  def all(filters) do
    Enum.filter(all(), fn model ->
      filters |> Enum.map(fn {output, type} -> Map.fetch!(model, output) == type end) |> Enum.all?()
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

  def model_url(%__MODULE__{platform: Vestaboard}) do
    "https://www.vestaboard.com"
  end

  def model_url(%__MODULE__{platform: Replicate, path: path}) do
    "https://replicate.com/#{path}"
  end
end
