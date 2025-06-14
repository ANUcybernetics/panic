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

  alias Panic.Platforms.Gemini
  alias Panic.Platforms.OpenAI
  alias Panic.Platforms.Replicate
  alias Panic.Platforms.Vestaboard

  require Logger

  @vestaboard_sleep to_timeout(second: 5)

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
      # Gemini (Google AI)
      %__MODULE__{
        id: "gemini-audio-description",
        name: "Gemini Audio Description (Flash)",
        path: "gemini-2.5-flash-preview-05-20",
        input_type: :audio,
        output_type: :text,
        platform: Gemini,
        invoke: fn model, audio_file, token ->
          Gemini.invoke(
            model,
            %{
              audio_file: audio_file,
              prompt: "In simple language, describe this music and the feeling or vibe it evokes"
            },
            token
          )
        end
      },
      # Gemini (Google AI)
      %__MODULE__{
        id: "gemini-audio-description-pro",
        name: "Gemini Audio Description (Pro)",
        path: "gemini-2.5-pro-preview-06-05",
        input_type: :audio,
        output_type: :text,
        platform: Gemini,
        invoke: fn model, audio_file, token ->
          Gemini.invoke(
            model,
            %{
              audio_file: audio_file,
              prompt: "In simple language, describe this music and the feeling or vibe it evokes"
            },
            token
          )
        end
      },
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
        id: "clip-caption-reward",
        platform: Replicate,
        path: "j-min/clip-caption-reward",
        name: "CLIP caption reward",
        input_type: :image,
        output_type: :text,
        invoke: fn model, input, token ->
          with {:ok, %{"output" => text}} <-
                 Replicate.invoke(
                   model,
                   %{
                     image: input,
                     reward: Enum.random(["mle", "cider", "clips", "cider_clips", "clips_grammar"])
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
        id: "joy-caption",
        platform: Replicate,
        path: "pipi32167/joy-caption",
        name: "Joy Caption",
        input_type: :image,
        output_type: :text,
        invoke: fn model, input, token ->
          with {:ok, %{"output" => text}} <-
                 Replicate.invoke(
                   model,
                   %{
                     image: input,
                     prompt:
                       "Provide an interesting, concise caption for this image. Describe foreground and background elements."
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
        id: "flux-texture-abstract-painting",
        platform: Replicate,
        path: "brunnolou/flux-texture-abstract-painting",
        name: "FLUX Abstract Painting",
        input_type: :text,
        output_type: :image,
        invoke: fn model, input, token ->
          input_params = %{
            prompt: input <> " The image is in the style of TXTUR.",
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
        id: "zine-style",
        platform: Replicate,
        path: "roblester/zine-style",
        name: "SDXL Zine",
        input_type: :text,
        output_type: :image,
        invoke: fn model, input, token ->
          input_params = %{
            prompt: input <> ", illustration in the style of TOK",
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
        id: "imagen-3-fast",
        platform: Replicate,
        path: "google/imagen-3-fast",
        name: "Imagen 3 Fast",
        input_type: :text,
        output_type: :image,
        invoke: fn model, input, token ->
          input_params = %{
            prompt: input,
            aspect_ratio: "16:9",
            safety_filter_level: "block_only_high"
          }

          with {:ok, %{"output" => image_url}} <-
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
        id: "meta-llama-3-70b-instruct",
        platform: Replicate,
        path: "meta/meta-llama-3-70b-instruct",
        name: "LLaMa 70B Instruct",
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
        id: "musicgen",
        platform: Replicate,
        path: "meta/musicgen",
        name: "MusicGen",
        input_type: :text,
        output_type: :audio,
        invoke: fn model, input, token ->
          with {:ok, %{"output" => audio_url}} <-
                 Replicate.invoke(
                   model,
                   %{
                     model_version: "melody-large",
                     prompt: input,
                     duration: 8,
                     multi_band_diffusion: true,
                     output_format: "mp3"
                   },
                   token
                 ) do
            {:ok, audio_url}
          end
        end
      },
      %__MODULE__{
        id: "stable-audio",
        platform: Replicate,
        path: "ardianfe/stable-audio-prod",
        name: "Stable Audio Open",
        input_type: :text,
        output_type: :audio,
        invoke: fn model, input, token ->
          with {:ok, %{"output" => %{"output" => audio_url}}} <-
                 Replicate.invoke(
                   model,
                   %{
                     prompt: input,
                     duration: 8,
                     output_format: "mp3",
                     song_id: :rand.uniform(1_000_000)
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
        id: "bark",
        platform: Replicate,
        path: "suno-ai/bark",
        name: "Bark",
        input_type: :text,
        output_type: :audio,
        invoke: fn model, input, token ->
          with {:ok, %{"output" => %{"audio_out" => audio_url}}} <-
                 Replicate.invoke(
                   model,
                   %{
                     prompt: input,
                     text_temp: 0.9,
                     waveform_temp: 0.9,
                     history_prompt: "en_speaker_#{Enum.random(0..9)}"
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
      }
    ] ++
      Enum.map(
        [
          {"vestaboard-panic-1", "panic_1", "Vestaboard Panic 1"},
          {"vestaboard-panic-2", "panic_2", "Vestaboard Panic 2"},
          {"vestaboard-panic-3", "panic_3", "Vestaboard Panic 3"},
          {"vestaboard-panic-4", "panic_4", "Vestaboard Panic 4"}
        ],
        fn {id, path, name} ->
          %__MODULE__{
            id: id,
            platform: Vestaboard,
            path: path,
            name: name,
            input_type: :text,
            output_type: :text,
            invoke: fn model, input, token ->
              case Vestaboard.send_text(model, input, token) do
                {:ok, _} -> Process.sleep(@vestaboard_sleep)
                {:error, reason} -> Logger.warning("Vestaboard error: #{inspect(reason)}")
              end

              {:ok, input}
            end
          }
        end
      )
  end

  def all(filters) do
    Enum.filter(all(), fn model ->
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

  def model_url(%__MODULE__{platform: Vestaboard}) do
    "https://www.vestaboard.com"
  end

  def model_url(%__MODULE__{platform: Replicate, path: path}) do
    "https://replicate.com/#{path}"
  end

  # these are helper functions for dealing with the Network :models attribute,
  # which (in the db) is an array of (nonempty) arrays of model id strings
  # the last item of each subarray is always a "real" model
  # any preceeding items are vestaboards which should be set to the model's input
  def model_ids_to_model_list(model_ids) do
    model_ids
    |> List.flatten()
    |> Enum.map(&by_id!/1)
  end

  def model_list_to_model_ids(model_list) do
    model_list
    |> Enum.reverse()
    |> Enum.reduce([], fn
      %__MODULE__{id: id, platform: Vestaboard}, [first | rest] -> [[id | first] | rest]
      %__MODULE__{id: id}, acc -> [[id] | acc]
    end)
  end

  @doc """
  Transforms a list of models into a list of tuples containing model information with indices.

  This function takes a list of models and returns a list of tuples. Each tuple contains:
  - The original index of the model in the input list
  - An "actual index" that increments only for non-Vestaboard models
  - The model itself

  Vestaboard models are assigned `nil` as their actual index (because they're not
  really models).

  ## Parameters

  - `models`: A list of `Panic.Model` structs

  ## Returns

  A list of tuples in the format `{original_index, actual_index, model}`, where:
  - `original_index` is the index of the model in the input list
  - `actual_index` is the index excluding Vestaboard models, or `nil` for Vestaboard models
  - `model` is the original model struct

  ## Example

      iex> models = [%Panic.Model{platform: Vestaboard}, %Panic.Model{}, %Panic.Model{}]
      iex> Panic.Model.models_with_indices(models)
      [{0, nil, %Panic.Model{platform: Vestaboard}}, {1, 0, %Panic.Model{}}, {2, 1, %Panic.Model{}}]
  """
  def models_with_indices(models) do
    models
    |> Enum.with_index()
    |> Enum.reduce({[], 0}, fn {model, index}, {acc, actual_index} ->
      case model.platform do
        Vestaboard ->
          {[{index, nil, model} | acc], actual_index}

        _ ->
          {[{index, actual_index, model} | acc], actual_index + 1}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
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
