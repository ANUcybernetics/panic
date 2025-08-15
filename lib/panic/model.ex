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

  alias Panic.Platforms.Dummy
  alias Panic.Platforms.Gemini
  alias Panic.Platforms.OpenAI
  alias Panic.Platforms.Replicate

  require Logger

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
          platform: OpenAI | Replicate,
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
      %__MODULE__{
        id: "gemini-audio-description",
        name: "Gemini Audio Description (Flash)",
        path: "gemini-2.5-flash",
        input_type: :audio,
        output_type: :text,
        platform: Gemini,
        invoke: fn model, audio_file, token ->
          Gemini.invoke(
            model,
            %{
              audio_file: audio_file,
              prompt: """
              Describe this audio. The description will be fed into a text-to-audio generative model,
              and your aim is to have that model reproduce the original audio as closely as possible.
              Never include any specific artist or song names in the description.

              Be concise - less than 100 words in total.
              """
            },
            token
          )
        end
      },
      %__MODULE__{
        id: "gemini-audio-description-pro",
        name: "Gemini Audio Description (Pro)",
        path: "gemini-2.5-pro",
        input_type: :audio,
        output_type: :text,
        platform: Gemini,
        invoke: fn model, audio_file, token ->
          Gemini.invoke(
            model,
            %{
              audio_file: audio_file,
              prompt: """
              Describe this audio. The description will be fed into a text-to-audio generative model,
              and your aim is to have that model reproduce the original audio as closely as possible.
              Never include any specific artist or song names in the description.

              Be concise - less than 100 words in total.
              """
            },
            token
          )
        end
      },
      ## OpenAI
      %__MODULE__{
        id: "gpt-5-chat",
        path: "gpt-5-chat-latest",
        name: "GPT-5 Chat",
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
                       "Provide an interesting, concise caption for this image. Describe foreground and background elements.",
                     max_new_tokens: 50
                   },
                   token
                 ) do
            {:ok, text}
          end
        end
      },
      %__MODULE__{
        id: "florence-2-large",
        platform: Replicate,
        path: "lucataco/florence-2-large",
        name: "Florence 2",
        input_type: :image,
        output_type: :text,
        invoke: fn model, input, token ->
          with {:ok, %{"output" => %{"text" => text}}} <-
                 Replicate.invoke(model, %{image: input, task_input: "Detailed Caption"}, token),
               {:ok, %{"DETAILED_CAPTION" => caption}} <- JsonFixer.parse_incorrect_json(text) do
            {:ok, caption}
          end
        end
      },
      %__MODULE__{
        id: "uform-gen",
        platform: Replicate,
        path: "zsxkib/uform-gen",
        name: "UForm",
        input_type: :image,
        output_type: :text,
        invoke: fn model, input, token ->
          with {:ok, %{"output" => text}} <-
                 Replicate.invoke(
                   model,
                   %{image: input, prompt: "Describe the image in great detail"},
                   token
                 ) do
            {:ok, text}
          end
        end
      },
      %__MODULE__{
        id: "molmo-7b",
        platform: Replicate,
        path: "zsxkib/molmo-7b",
        name: "Molmo 7B-D",
        input_type: :image,
        output_type: :text,
        invoke: fn model, input, token ->
          with {:ok, %{"output" => text}} <-
                 Replicate.invoke(
                   model,
                   %{
                     image: input,
                     text: "What do you see? Give me a detailed answer",
                     max_new_tokens: 100
                   },
                   token
                 ) do
            {:ok, text}
          end
        end
      },
      %__MODULE__{
        id: "moondream2",
        platform: Replicate,
        path: "lucataco/moondream2",
        name: "Moondream 2",
        input_type: :image,
        output_type: :text,
        invoke: fn model, input, token ->
          with {:ok, %{"output" => text_array}} <-
                 Replicate.invoke(
                   model,
                   %{
                     image: input,
                     question:
                       "Provide a very short description of this picture, including both foreground and background elements, and the (artistic) style of the image."
                   },
                   token
                 ) do
            {:ok, text_array |> Enum.join("") |> String.trim()}
          end
        end
      },
      %__MODULE__{
        id: "blip-2",
        platform: Replicate,
        path: "salesforce/blip-2",
        name: "BLIP 2",
        input_type: :image,
        output_type: :text,
        invoke: fn model, input, token ->
          with {:ok, %{"output" => text}} <-
                 Replicate.invoke(
                   model,
                   %{
                     image: input,
                     question:
                       "Describe this picture in detail, including both foreground and background elements, and the (artistic) style of the image."
                   },
                   token
                 ) do
            {:ok, text}
          end
        end
      },
      %__MODULE__{
        id: "blip-3",
        platform: Replicate,
        path: "zsxkib/blip-3",
        name: "BLIP 3",
        input_type: :image,
        output_type: :text,
        invoke: fn model, input, token ->
          with {:ok, %{"output" => text}} <-
                 Replicate.invoke(
                   model,
                   %{
                     image: input,
                     question: "What is shown in the image, and what (artistic) style does the image represent?"
                   },
                   token
                 ) do
            {:ok, text}
          end
        end
      },
      %__MODULE__{
        id: "stable-diffusion",
        platform: Replicate,
        path: "stability-ai/stable-diffusion-3.5-large-turbo",
        name: "Stable Diffusion 3.5 Turbo",
        input_type: :text,
        output_type: :image,
        invoke: fn model, input, token ->
          input_params = %{
            prompt: input,
            aspect_ratio: "16:9",
            output_format: "png"
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
            output_format: "png",
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
      %__MODULE__{
        id: "icons",
        platform: Replicate,
        path: "galleri5/icons",
        name: "SDXL Icons",
        input_type: :text,
        output_type: :image,
        invoke: fn model, input, token ->
          input_params = %{
            prompt: input,
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
        id: "sticker-maker",
        platform: Replicate,
        path: "fofr/sticker-maker",
        name: "Sticker Maker",
        input_type: :text,
        output_type: :image,
        invoke: fn model, input, token ->
          input_params = %{
            prompt: input,
            output_format: "png",
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
        id: "sdxl-lightning-4step",
        platform: Replicate,
        path: "bytedance/sdxl-lightning-4step",
        name: "SDXL Lightning",
        input_type: :text,
        output_type: :image,
        invoke: fn model, input, token ->
          input_params = %{
            prompt: input,
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
        id: "kandinsky-2.2",
        platform: Replicate,
        path: "ai-forever/kandinsky-2.2",
        name: "Kandinsky 2.2",
        input_type: :text,
        output_type: :image,
        invoke: fn model, input, token ->
          input_params = %{
            prompt: input,
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
        id: "proteus-v0.2",
        platform: Replicate,
        path: "datacte/proteus-v0.2",
        name: "Proteus v0.2",
        input_type: :text,
        output_type: :image,
        invoke: fn model, input, token ->
          input_params = %{
            prompt: input,
            width: 1024,
            height: 576,
            apply_watermark: false,
            disable_safety_checker: true
          }

          with {:ok, %{"output" => [image_url]}} <-
                 Replicate.invoke(model, input_params, token) do
            {:ok, image_url}
          end
        end
      },
      %__MODULE__{
        id: "imagen-4-fast",
        platform: Replicate,
        path: "google/imagen-4-fast",
        name: "Imagen 4 Fast",
        input_type: :text,
        output_type: :image,
        invoke: fn model, input, token ->
          input_params = %{
            prompt: input,
            aspect_ratio: "16:9",
            safety_filter_level: "block_only_high"
          }

          with {:ok, %{"output" => image_url}} when is_binary(image_url) and image_url != "" <-
                 Replicate.invoke(model, input_params, token) do
            {:ok, image_url}
          end
        end
      },
      %__MODULE__{
        id: "photon-flash",
        platform: Replicate,
        path: "luma/photon-flash",
        name: "Luma Photon Flash",
        input_type: :text,
        output_type: :image,
        invoke: fn model, input, token ->
          input_params = %{
            prompt: input,
            aspect_ratio: "16:9"
          }

          with {:ok, %{"output" => image_url}} <-
                 Replicate.invoke(model, input_params, token) do
            {:ok, image_url}
          end
        end
      },
      %__MODULE__{
        id: "seedream-3",
        platform: Replicate,
        path: "bytedance/seedream-3",
        name: "Seedream 3",
        description: "High-quality text-to-image generation model from ByteDance",
        input_type: :text,
        output_type: :image,
        invoke: fn model, input, token ->
          input_params = %{
            prompt: input,
            aspect_ratio: "16:9",
            size: "big",
            guidance_scale: 2.5
          }

          with {:ok, %{"output" => image_url}} <-
                 Replicate.invoke(model, input_params, token) do
            {:ok, image_url}
          end
        end
      },
      %__MODULE__{
        id: "dreamina-3.1",
        platform: Replicate,
        path: "bytedance/dreamina-3.1",
        name: "Dreamina 3.1",
        description: "4MP cinematic-quality text-to-image generation with precise style control from ByteDance",
        input_type: :text,
        output_type: :image,
        invoke: fn model, input, token ->
          input_params = %{
            prompt: input,
            aspect_ratio: "16:9",
            resolution: "2K",
            enhance_prompt: false
          }

          with {:ok, %{"output" => image_url}} <-
                 Replicate.invoke(model, input_params, token) do
            {:ok, image_url}
          end
        end
      },
      %__MODULE__{
        id: "ideogram-v3-turbo",
        platform: Replicate,
        path: "ideogram-ai/ideogram-v3-turbo",
        name: "Ideogram V3 Turbo",
        description: "Fast text-to-image generation with stunning realism, creative designs, and consistent styles",
        input_type: :text,
        output_type: :image,
        invoke: fn model, input, token ->
          input_params = %{
            prompt: input,
            aspect_ratio: "16:9"
          }

          with {:ok, %{"output" => image_url}} <-
                 Replicate.invoke(model, input_params, token) do
            {:ok, image_url}
          end
        end
      },
      %__MODULE__{
        id: "claude-4-sonnet",
        platform: Replicate,
        path: "anthropic/claude-4-sonnet",
        name: "Claude 4 Sonnet",
        input_type: :text,
        output_type: :text,
        invoke: fn model, input, token ->
          with {:ok, %{"output" => output_list}} <-
                 Replicate.invoke(model, %{prompt: input}, token) do
            {:ok, Enum.join(output_list)}
          end
        end
      },
      %__MODULE__{
        id: "claude-4-sonnet-caption",
        platform: Replicate,
        path: "anthropic/claude-4-sonnet",
        name: "Claude 4 Sonnet Caption",
        input_type: :image,
        output_type: :text,
        invoke: fn model, input, token ->
          with {:ok, %{"output" => output_list}} <-
                 Replicate.invoke(
                   model,
                   %{
                     prompt: "describe this image in one sentence",
                     image: input,
                     max_image_resolution: 0.5
                   },
                   token
                 ) do
            {:ok, Enum.join(output_list)}
          end
        end
      },
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
      %__MODULE__{
        id: "meta-llama-3-8b-songifier",
        platform: Replicate,
        path: "meta/meta-llama-3-8b-instruct",
        name: "LLaMa Songifier",
        input_type: :text,
        output_type: :text,
        invoke: fn model, input, token ->
          input = """
          You are an expert music producer with skills in an extremely wide range of musical genres and styles.
          Interpret the following text as the design brief for a song, and reply with a one-sentence
          description of the song. You may include details like bpm, instrumentation, genre/feel, but
          reply only with the one-sentence description (do not say "Certainly", or "Here is the description"
          or anything other than the song description itself).

          #{input}
          """

          with {:ok, %{"output" => output_list}} <-
                 Replicate.invoke(model, %{prompt: input}, token) do
            {:ok, Enum.join(output_list)}
          end
        end
      },
      %__MODULE__{
        id: "musicgen",
        platform: Replicate,
        path: "ardianfe/music-gen-fn-200e",
        name: "MusicGen",
        input_type: :text,
        output_type: :audio,
        invoke: fn model, input, token ->
          with {:ok, %{"output" => audio_url}} <-
                 Replicate.invoke(
                   model,
                   %{
                     prompt: input,
                     duration: 8,
                     # multi_band_diffusion: true,
                     top_k: 1000,
                     temperature: 1.1,
                     output_format: "mp3"
                   },
                   token
                 ) do
            {:ok, audio_url}
          end
        end
      },
      %__MODULE__{
        id: "magnet",
        platform: Replicate,
        path: "lucataco/magnet",
        name: "MAGNeT",
        input_type: :text,
        output_type: :audio,
        invoke: fn model, input, token ->
          with {:ok, %{"output" => [audio_url]}} <-
                 Replicate.invoke(
                   model,
                   %{
                     prompt: input,
                     model: "facebook/magnet-medium-10secs",
                     variations: 1
                   },
                   token
                 ) do
            {:ok, audio_url}
          end
        end
      },
      %__MODULE__{
        id: "flux-music",
        platform: Replicate,
        path: "zsxkib/flux-music",
        name: "Flux Music",
        input_type: :text,
        output_type: :audio,
        invoke: fn model, input, token ->
          with {:ok, %{"output" => %{"wav" => audio_url}}} <-
                 Replicate.invoke(
                   model,
                   %{
                     prompt: input,
                     model_version: "base",
                     steps: 50
                   },
                   token
                 ) do
            {:ok, audio_url}
          end
        end
      },
      %__MODULE__{
        id: "riffusion",
        platform: Replicate,
        path: "riffusion/riffusion",
        name: "Riffusion",
        input_type: :text,
        output_type: :audio,
        invoke: fn model, input, token ->
          with {:ok, %{"output" => %{"audio" => audio_url}}} <-
                 Replicate.invoke(
                   model,
                   %{
                     prompt_a: input,
                     alpha: 0,
                     seed_image_id:
                       Enum.random([
                         "agile",
                         "marim",
                         "motorway",
                         "og_beat",
                         "vibes"
                       ])
                   },
                   token
                 ) do
            {:ok, audio_url}
          end
        end
      },
      %__MODULE__{
        id: "lyria-2",
        platform: Replicate,
        path: "google/lyria-2",
        name: "Lyria 2",
        description: "Lyria 2 is a music generation model that produces 48kHz stereo audio through text-based prompts",
        input_type: :text,
        output_type: :audio,
        invoke: fn model, input, token ->
          with {:ok, %{"output" => audio_url}} <-
                 Replicate.invoke(model, %{prompt: input}, token) do
            {:ok, audio_url}
          end
        end
      },
      %__MODULE__{
        id: "whisper",
        platform: Replicate,
        path: "openai/whisper",
        name: "Whisper",
        input_type: :audio,
        output_type: :text,
        invoke: fn model, input, token ->
          with {:ok, %{"output" => %{"transcription" => text}}} <-
                 Replicate.invoke(
                   model,
                   %{
                     audio: input,
                     transcription: "plain text",
                     condition_on_previous_text: false,
                     # set this super high so that it tries to guess something
                     no_speech_threshold: 1.0
                   },
                   token
                 ) do
            {:ok, text}
          end
        end
      },
      %__MODULE__{
        id: "image-reproducer-i-flux",
        platform: Replicate,
        path: "black-forest-labs/flux-kontext-dev",
        name: "Image Reproducer I (Flux)",
        description: "Image generation/reproduction model that can create images from text or reproduce existing images",
        input_type: :text,
        output_type: :image,
        invoke: fn model, input, token ->
          # Check if input looks like a URL (for image reproduction)
          # or text prompt (for genesis)
          if String.starts_with?(input, "http") do
            # Image reproduction mode
            input_params = %{
              prompt: "reproduce this image exactly",
              input_image: input,
              guidance: 2.5,
              num_inference_steps: 30,
              output_format: "png",
              aspect_ratio: "16:9"
            }

            with {:ok, %{"output" => image_url}} <-
                   Replicate.invoke(model, input_params, token) do
              {:ok, image_url}
            end
          else
            # Genesis mode - use flux-schnell to generate initial image
            flux_schnell_model = %__MODULE__{
              id: "flux-schnell",
              path: "black-forest-labs/flux-schnell",
              name: "FLUX.1 [schnell]",
              platform: Replicate,
              input_type: :text,
              output_type: :image,
              invoke: fn _, _, _ -> {:ok, ""} end
            }

            input_params = %{
              prompt: input,
              output_format: "png",
              aspect_ratio: "16:9",
              disable_safety_checker: true
            }

            with {:ok, %{"output" => [image_url]}} <-
                   Replicate.invoke(flux_schnell_model, input_params, token) do
              {:ok, image_url}
            end
          end
        end
      },
      %__MODULE__{
        id: "image-reproducer-ii-flux",
        platform: Replicate,
        path: "black-forest-labs/flux-kontext-dev",
        name: "Image Reproducer II (Flux)",
        description: "Image to text passthrough for completing image reproduction networks",
        input_type: :image,
        output_type: :text,
        invoke: fn _model, input, _token ->
          # Simply pass through the image URL as text
          # This allows the network to complete the cycle
          {:ok, input}
        end
      },
      %__MODULE__{
        id: "image-reproducer-i-seed",
        platform: Replicate,
        path: "bytedance/seededit-3.0",
        name: "Image Reproducer I (Seed)",
        description: "Image generation/reproduction model that can create images from text or reproduce existing images",
        input_type: :text,
        output_type: :image,
        invoke: fn model, input, token ->
          # Check if input looks like a URL (for image reproduction)
          # or text prompt (for genesis)
          if String.starts_with?(input, "http") do
            # Image reproduction mode
            input_params = %{
              prompt: "reproduce this image exactly",
              image: input,
              guidance_scale: 5.5
            }

            with {:ok, %{"output" => image_url}} <-
                   Replicate.invoke(model, input_params, token) do
              {:ok, image_url}
            end
          else
            # Genesis mode - use seedream-3 to generate initial image
            seedream_model = %__MODULE__{
              id: "seedream-3",
              path: "bytedance/seedream-3",
              name: "Seedream 3",
              platform: Replicate,
              input_type: :text,
              output_type: :image,
              invoke: fn _, _, _ -> {:ok, ""} end
            }

            input_params = %{
              prompt: input,
              aspect_ratio: "16:9",
              size: "big",
              guidance_scale: 2.5
            }

            with {:ok, %{"output" => image_url}} <-
                   Replicate.invoke(seedream_model, input_params, token) do
              {:ok, image_url}
            end
          end
        end
      },
      %__MODULE__{
        id: "image-reproducer-ii-seed",
        platform: Replicate,
        path: "bytedance/seededit-3.0",
        name: "Image Reproducer II (Seed)",
        description: "Image to text passthrough for completing image reproduction networks",
        input_type: :image,
        output_type: :text,
        invoke: fn _model, input, _token ->
          # Simply pass through the image URL as text
          # This allows the network to complete the cycle
          {:ok, input}
        end
      }
    ] ++
      [
        # Text to Text
        %__MODULE__{
          id: "dummy-t2t",
          platform: Dummy,
          path: "dummy/text-to-text",
          name: "Dummy Text-to-Text",
          input_type: :text,
          output_type: :text,
          description: "Dummy model for testing text-to-text transformations",
          invoke: fn model, input, token ->
            Dummy.invoke(model, input, token)
          end
        },
        # Text to Image
        %__MODULE__{
          id: "dummy-t2i",
          platform: Dummy,
          path: "dummy/text-to-image",
          name: "Dummy Text-to-Image",
          input_type: :text,
          output_type: :image,
          description: "Dummy model for testing text-to-image generation",
          invoke: fn model, input, token ->
            Dummy.invoke(model, input, token)
          end
        },
        # Text to Audio
        %__MODULE__{
          id: "dummy-t2a",
          platform: Dummy,
          path: "dummy/text-to-audio",
          name: "Dummy Text-to-Audio",
          input_type: :text,
          output_type: :audio,
          description: "Dummy model for testing text-to-audio generation",
          invoke: fn model, input, token ->
            Dummy.invoke(model, input, token)
          end
        },
        # Image to Text
        %__MODULE__{
          id: "dummy-i2t",
          platform: Dummy,
          path: "dummy/image-to-text",
          name: "Dummy Image-to-Text",
          input_type: :image,
          output_type: :text,
          description: "Dummy model for testing image captioning",
          invoke: fn model, input, token ->
            Dummy.invoke(model, input, token)
          end
        },
        # Image to Image
        %__MODULE__{
          id: "dummy-i2i",
          platform: Dummy,
          path: "dummy/image-to-image",
          name: "Dummy Image-to-Image",
          input_type: :image,
          output_type: :image,
          description: "Dummy model for testing image transformation",
          invoke: fn model, input, token ->
            Dummy.invoke(model, input, token)
          end
        },
        # Image to Audio
        %__MODULE__{
          id: "dummy-i2a",
          platform: Dummy,
          path: "dummy/image-to-audio",
          name: "Dummy Image-to-Audio",
          input_type: :image,
          output_type: :audio,
          description: "Dummy model for testing image-to-audio generation",
          invoke: fn model, input, token ->
            Dummy.invoke(model, input, token)
          end
        },
        # Audio to Text
        %__MODULE__{
          id: "dummy-a2t",
          platform: Dummy,
          path: "dummy/audio-to-text",
          name: "Dummy Audio-to-Text",
          input_type: :audio,
          output_type: :text,
          description: "Dummy model for testing audio transcription",
          invoke: fn model, input, token ->
            Dummy.invoke(model, input, token)
          end
        },
        # Audio to Image
        %__MODULE__{
          id: "dummy-a2i",
          platform: Dummy,
          path: "dummy/audio-to-image",
          name: "Dummy Audio-to-Image",
          input_type: :audio,
          output_type: :image,
          description: "Dummy model for testing audio-to-image generation",
          invoke: fn model, input, token ->
            Dummy.invoke(model, input, token)
          end
        },
        # Audio to Audio
        %__MODULE__{
          id: "dummy-a2a",
          platform: Dummy,
          path: "dummy/audio-to-audio",
          name: "Dummy Audio-to-Audio",
          input_type: :audio,
          output_type: :audio,
          description: "Dummy model for testing audio transformation",
          invoke: fn model, input, token ->
            Dummy.invoke(model, input, token)
          end
        }
      ]
  end

  def all(filters) do
    Enum.filter(all(), fn model ->
      filters
      |> Enum.map(fn {output, type} -> Map.fetch!(model, output) == type end)
      |> Enum.all?()
    end)
  end

  def by_id(id) do
    case all(id: id) do
      [] -> nil
      [model] -> model
      _ -> nil
    end
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

  def model_url(%__MODULE__{platform: Gemini}) do
    "https://ai.google.dev/gemini-api/docs"
  end

  def model_url(%__MODULE__{platform: Replicate, path: path}) do
    "https://replicate.com/#{path}"
  end

  def model_url(%__MODULE__{platform: Dummy}) do
    "#dummy-platform"
  end

  @doc """
  Transforms a list of models into a list of tuples containing model information with indices.

  This function takes a list of models and returns a list of tuples. Each tuple contains:
  - The original index of the model in the input list
  - An "actual index" that matches the original index
  - The model itself

  ## Parameters

  - `models`: A list of `Panic.Model` structs

  ## Returns

  A list of tuples in the format `{original_index, actual_index, model}`, where:
  - `original_index` is the index of the model in the input list
  - `actual_index` is the same as the original index
  - `model` is the original model struct

  ## Example

      iex> models = [%Panic.Model{}, %Panic.Model{}]
      iex> Panic.Model.models_with_indices(models)
      [{0, 0, %Panic.Model{}}, {1, 1, %Panic.Model{}}]
  """
  def models_with_indices(models) do
    models
    |> Enum.with_index()
    |> Enum.map(fn {model, index} -> {index, index, model} end)
  end
end

# TODO maybe this should go in it's own file? Hopefully they fix the cog return stuff
# and it can just be deleted
defmodule JsonFixer do
  @moduledoc """
  Provides functionality to parse and fix incorrectly formatted JSON strings.

  This module offers methods to handle JSON-like strings that use single quotes
  instead of double quotes, and may contain escaped characters within the values.
  It's particularly useful for parsing JSON that has been incorrectly formatted
  but still maintains a valid structure.

  Currently, this is necessary because [florence-2-large](https://replicate.com/lucataco/florence-2-large)
  returns poorly formed responses.
  """
  def parse_incorrect_json(input) do
    fixed_json =
      input
      |> replace_outer_quotes()
      |> String.replace("<DETAILED_CAPTION>", "DETAILED_CAPTION")

    case Jason.decode(fixed_json) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _} -> {:error, "Failed to parse JSON"}
    end
  end

  defp replace_outer_quotes(input) do
    regex = ~r/\{'(.+?)': '((?:[^'\\]|\\.)*)'}/

    Regex.replace(regex, input, fn _, key, value ->
      escaped_value =
        value
        |> String.replace("\\", "\\\\")
        |> String.replace("\"", "\\\"")

      ~s({"#{key}": "#{escaped_value}"})
    end)
  end
end
