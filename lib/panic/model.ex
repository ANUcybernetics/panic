defmodule Panic.Model do
  @moduledoc """
  Struct containing all the model info:

  - `id`: string used as a unique identifier for the model
  - `path`: path to the hosted model (exactly how that translates into the final URL depends on the platform)
  - `name`: human readable name for the model
  - `description`: brief description of the model (supports markdown)
  - `input_type`: input type (either `:text`, `:image` or `:audio`)
  - `output_type`: output type (either `:text`, `:image` or `:audio`)
  - `params`: turns the invocation's input into the platform request's input
  - `output`: picks the output out of the platform's response (see `Panic.Model.Output`)
  - `invoke`: for a model that makes more than one platform call (or none), a
    function of `model`, `input` and `token` that replaces `params` and `output`
    and returns what `invoke/3` does

  Models are defined in code (rather than in the database) because each needs
  bespoke code to build its request and pull out its output. You can squint at
  this module as a Repo of models.
  """
  @behaviour Access

  alias Panic.Model.Output
  alias Panic.Platforms.Dummy
  alias Panic.Platforms.Gemini
  alias Panic.Platforms.OpenAI
  alias Panic.Platforms.Replicate
  alias Panic.Watcher.Vestaboards

  # Each Vestaboard captioner looks at the image through a different lens, so a
  # run drifts rather than converging on one faithfully re-described scene.
  @describe_lens """
  Describe this image vividly in two or three sentences: subject, setting, the strangest or most \
  specific details, and the visual style or medium (photo, painting, render, etc).\
  """
  @uncanny_lens """
  Look closely at this image and describe what is odd, wrong or uncanny about it: garbled text, \
  impossible anatomy or physics, objects that don't belong, anything a careful viewer would notice. \
  Two or three sentences.\
  """
  @film_still_lens """
  Treat this image as a single frame from a film. In two or three sentences, say what has just \
  happened, what is about to happen, and the genre of the film.\
  """
  @critic_lens """
  Describe this image as an art critic would, in two or three sentences: the medium, technique, \
  palette and mood first, then the subject.\
  """
  @condense_prompt """
  Rewrite the image description below as a caption for a Vestaboard split-flap display, which shows \
  6 lines of 22 characters. Hard limit: 90 characters, about 14 words. Keep its most surprising idea, \
  and any art style or medium it names. One plain sentence; no quotation marks, dashes, emoji or line \
  breaks. Reply with the caption only.\
  """
  @audio_description_prompt """
  Describe this audio. The description will be fed into a text-to-audio generative model,
  and your aim is to have that model reproduce the original audio as closely as possible.
  Never include any specific artist or song names in the description.

  Be concise - less than 100 words in total.
  """
  @caption_prompt "Provide an interesting, concise caption for this image. Describe foreground and background elements."

  @enforce_keys [:id, :path, :name, :platform, :input_type, :output_type]
  defstruct [
    :id,
    :path,
    :name,
    :platform,
    :input_type,
    :output_type,
    :description,
    :homepage,
    :invoke,
    params: &Function.identity/1,
    output: &Output.as_is/1,
    deprecated: false
  ]

  @typedoc """
  What one platform call consumed, as the platform reported it: a string-keyed
  map with the `"platform"` and `"path"` called and whichever of the metrics
  `Panic.Engine.Footprint` prices it reported.
  """
  @type usage :: %{String.t() => term()}

  @type t :: %__MODULE__{
          id: String.t(),
          path: String.t(),
          name: String.t(),
          platform: module(),
          input_type: :text | :audio | :image,
          output_type: :text | :audio | :image,
          description: String.t() | nil,
          homepage: String.t() | nil,
          params: (term() -> term()),
          output: (term() -> {:ok, String.t()} | {:error, term()}),
          invoke: (t(), term(), String.t() -> {:ok, String.t(), [usage()]} | {:error, term()}) | nil,
          deprecated: boolean()
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

  @doc """
  Runs `model` on `input` with the platform `token`. Returns the output and the
  usage of each platform call that produced it, so the invocation can record
  what it cost (see `Panic.Engine.Footprint`).
  """
  @spec invoke(t(), term(), String.t() | nil) :: {:ok, String.t(), [usage()]} | {:error, term()}
  def invoke(%__MODULE__{invoke: invoke} = model, input, token) when is_function(invoke, 3) do
    invoke.(model, input, token)
  end

  def invoke(%__MODULE__{params: params} = model, input, token) do
    call(model, params.(input), token)
  end

  defp call(%__MODULE__{platform: platform, output: output} = model, params, token) do
    with {:ok, response, usage} <- platform.invoke(model, params, token),
         {:ok, result} <- output.(response) do
      {:ok, result, [usage]}
    end
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
        params: &%{audio_file: &1, prompt: @audio_description_prompt}
      },
      %__MODULE__{
        id: "gemini-audio-description-pro",
        name: "Gemini Audio Description (Pro)",
        path: "gemini-2.5-pro",
        input_type: :audio,
        output_type: :text,
        platform: Gemini,
        params: &%{audio_file: &1, prompt: @audio_description_prompt}
      },
      ## OpenAI
      %__MODULE__{
        id: "gpt-5-chat",
        path: "gpt-5-chat-latest",
        name: "GPT-5 Chat",
        deprecated: true,
        input_type: :text,
        output_type: :text,
        platform: OpenAI
      },
      %__MODULE__{
        id: "gpt-5.6-luna",
        path: "gpt-5.6-luna",
        name: "GPT-5.6 Luna",
        input_type: :text,
        output_type: :text,
        platform: OpenAI
      },

      ## Replicate
      %__MODULE__{
        id: "bunny-phi-2-siglip",
        platform: Replicate,
        path: "adirik/bunny-phi-2-siglip",
        name: "Bunny Phi 2 SigLIP",
        input_type: :image,
        output_type: :text,
        deprecated: true,
        params: &%{image: &1, prompt: @caption_prompt, max_new_tokens: 50},
        output: &Output.text/1
      },
      %__MODULE__{
        id: "florence-2-large",
        platform: Replicate,
        path: "lucataco/florence-2-large",
        name: "Florence 2",
        input_type: :image,
        output_type: :text,
        deprecated: true,
        params: &%{image: &1, task_input: "Detailed Caption"},
        output: fn response ->
          with {:ok, text} <- Output.key("text").(response),
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
        deprecated: true,
        params: &%{image: &1, prompt: "Describe the image in great detail"},
        output: &Output.text/1
      },
      %__MODULE__{
        id: "molmo-7b",
        platform: Replicate,
        path: "zsxkib/molmo-7b",
        name: "Molmo 7B-D",
        input_type: :image,
        output_type: :text,
        params: &%{image: &1, text: "What do you see? Give me a detailed answer", max_new_tokens: 100},
        output: fn response ->
          with {:ok, text} <- Output.text(response), do: {:ok, String.trim(text, "\"")}
        end
      },
      %__MODULE__{
        id: "moondream2",
        platform: Replicate,
        path: "lucataco/moondream2",
        name: "Moondream 2",
        deprecated: true,
        input_type: :image,
        output_type: :text,
        params:
          &%{
            image: &1,
            question:
              "Provide a very short description of this picture, including both foreground and background elements, and the (artistic) style of the image."
          },
        output: &Output.text/1
      },
      %__MODULE__{
        id: "blip-2",
        platform: Replicate,
        path: "salesforce/blip-2",
        name: "BLIP 2",
        input_type: :image,
        output_type: :text,
        deprecated: true,
        params:
          &%{
            image: &1,
            question:
              "Describe this picture in detail, including both foreground and background elements, and the (artistic) style of the image."
          },
        output: &Output.text/1
      },
      %__MODULE__{
        id: "blip-3",
        platform: Replicate,
        path: "zsxkib/blip-3",
        name: "BLIP 3",
        input_type: :image,
        output_type: :text,
        deprecated: true,
        params:
          &%{
            image: &1,
            question: "What is shown in the image, and what (artistic) style does the image represent?"
          },
        output: &Output.text/1
      },
      %__MODULE__{
        id: "llava-13b",
        platform: Replicate,
        path: "yorickvp/llava-13b",
        name: "LLaVA 13B",
        description: "General-purpose visual language model for image captioning and understanding",
        input_type: :image,
        output_type: :text,
        deprecated: true,
        params: &%{image: &1, prompt: @caption_prompt, max_tokens: 100, temperature: 0.2},
        output: &Output.text/1
      },
      %__MODULE__{
        id: "qwen2-vl-7b-instruct",
        platform: Replicate,
        path: "lucataco/qwen2-vl-7b-instruct",
        name: "Qwen2-VL 7B",
        description: "Modern visual language model with any-resolution image understanding",
        input_type: :image,
        output_type: :text,
        params: &%{media: &1, prompt: @caption_prompt},
        output: &Output.text/1
      },
      %__MODULE__{
        id: "llama-4-scout-instruct",
        platform: Replicate,
        path: "meta/llama-4-scout-instruct",
        name: "Llama 4 Scout",
        description: "Natively multimodal 17B-parameter model with 16 experts",
        input_type: :image,
        output_type: :text,
        params: &%{image: &1, prompt: @caption_prompt, max_tokens: 100},
        output: &Output.text/1
      },
      %__MODULE__{
        id: "stable-diffusion",
        platform: Replicate,
        path: "stability-ai/stable-diffusion-3.5-large-turbo",
        name: "Stable Diffusion 3.5 Turbo",
        input_type: :text,
        output_type: :image,
        params: &%{prompt: &1, aspect_ratio: "16:9", output_format: "png"},
        output: &Output.first_url/1
      },
      %__MODULE__{
        id: "flux-schnell",
        platform: Replicate,
        path: "black-forest-labs/flux-schnell",
        name: "FLUX.1 [schnell]",
        input_type: :text,
        output_type: :image,
        deprecated: true,
        params: &flux_schnell_params/1,
        output: &Output.first_url/1
      },
      %__MODULE__{
        id: "sdxl",
        platform: Replicate,
        path: "stability-ai/sdxl",
        name: "Stable Diffusion XL",
        input_type: :text,
        output_type: :image,
        deprecated: true,
        params: &%{prompt: &1, num_inference_steps: 50, guidance_scale: 7.5, width: 1024, height: 576},
        output: &Output.first_url/1
      },
      %__MODULE__{
        id: "icons",
        platform: Replicate,
        path: "galleri5/icons",
        name: "SDXL Icons",
        input_type: :text,
        output_type: :image,
        deprecated: true,
        params: &%{prompt: &1, guidance_scale: 7.5, width: 1024, height: 576},
        output: &Output.first_url/1
      },
      %__MODULE__{
        id: "sticker-maker",
        platform: Replicate,
        path: "fofr/sticker-maker",
        name: "Sticker Maker",
        input_type: :text,
        output_type: :image,
        deprecated: true,
        params: &%{prompt: &1, output_format: "png", width: 1024, height: 576},
        output: &Output.first_url/1
      },
      %__MODULE__{
        id: "sdxl-lightning-4step",
        platform: Replicate,
        path: "bytedance/sdxl-lightning-4step",
        name: "SDXL Lightning",
        input_type: :text,
        output_type: :image,
        deprecated: true,
        params: &%{prompt: &1, width: 1024, height: 576},
        output: &Output.first_url/1
      },
      %__MODULE__{
        id: "kandinsky-2.2",
        platform: Replicate,
        path: "ai-forever/kandinsky-2.2",
        name: "Kandinsky 2.2",
        input_type: :text,
        output_type: :image,
        deprecated: true,
        params: &%{prompt: &1, width: 1024, height: 576},
        output: &Output.first_url/1
      },
      %__MODULE__{
        id: "proteus-v0.2",
        platform: Replicate,
        path: "datacte/proteus-v0.2",
        name: "Proteus v0.2",
        input_type: :text,
        output_type: :image,
        deprecated: true,
        params:
          &%{
            prompt: &1,
            width: 1024,
            height: 576,
            apply_watermark: false,
            disable_safety_checker: true
          },
        output: &Output.first_url/1
      },
      %__MODULE__{
        id: "imagen-4-fast",
        platform: Replicate,
        path: "google/imagen-4-fast",
        name: "Imagen 4 Fast",
        input_type: :text,
        output_type: :image,
        params: &%{prompt: &1, aspect_ratio: "16:9", safety_filter_level: "block_only_high"},
        output: &Output.first_url/1
      },
      %__MODULE__{
        id: "photon-flash",
        platform: Replicate,
        path: "luma/photon-flash",
        name: "Luma Photon Flash",
        input_type: :text,
        output_type: :image,
        params: &%{prompt: &1, aspect_ratio: "16:9"},
        output: &Output.first_url/1
      },
      %__MODULE__{
        id: "seedream-3",
        platform: Replicate,
        path: "bytedance/seedream-3",
        name: "Seedream 3",
        description: "High-quality text-to-image generation model from ByteDance",
        input_type: :text,
        output_type: :image,
        deprecated: true,
        params: &%{prompt: &1, aspect_ratio: "16:9", size: "big", guidance_scale: 2.5},
        output: &Output.first_url/1
      },
      %__MODULE__{
        id: "flux-2-klein-4b",
        platform: Replicate,
        path: "black-forest-labs/flux-2-klein-4b",
        name: "FLUX 2 Klein 4B",
        description: "Sub-second inference T2I with text rendering, successor to FLUX.1 schnell",
        input_type: :text,
        output_type: :image,
        params: &%{prompt: &1, aspect_ratio: "16:9", output_format: "png"},
        output: &Output.first_url/1
      },
      %__MODULE__{
        id: "seedream-4.5",
        platform: Replicate,
        path: "bytedance/seedream-4.5",
        name: "Seedream 4.5",
        description: "Successor to Seedream 3 with stronger spatial understanding",
        input_type: :text,
        output_type: :image,
        params: &%{prompt: &1, aspect_ratio: "16:9", size: "2K", guidance_scale: 2.5},
        output: &Output.first_url/1
      },
      %__MODULE__{
        id: "z-image-turbo",
        platform: Replicate,
        path: "prunaai/z-image-turbo",
        name: "Z-Image Turbo",
        description: "Sub-second photorealistic image generation",
        input_type: :text,
        output_type: :image,
        params: &%{prompt: &1, aspect_ratio: "16:9"},
        output: &Output.first_url/1
      },
      %__MODULE__{
        id: "dreamina-3.1",
        platform: Replicate,
        path: "bytedance/dreamina-3.1",
        name: "Dreamina 3.1",
        description: "4MP cinematic-quality text-to-image generation with precise style control from ByteDance",
        deprecated: true,
        input_type: :text,
        output_type: :image,
        params: &%{prompt: &1, aspect_ratio: "16:9", resolution: "2K", enhance_prompt: false},
        output: &Output.first_url/1
      },
      %__MODULE__{
        id: "ideogram-v3-turbo",
        platform: Replicate,
        path: "ideogram-ai/ideogram-v3-turbo",
        name: "Ideogram V3 Turbo",
        description: "Fast text-to-image generation with stunning realism, creative designs, and consistent styles",
        input_type: :text,
        output_type: :image,
        params: &%{prompt: &1, aspect_ratio: "16:9"},
        output: &Output.first_url/1
      },
      %__MODULE__{
        id: "nano-banana-2-lite",
        platform: Replicate,
        path: "google/nano-banana-2-lite",
        name: "Nano Banana 2 Lite",
        description: "Google's fastest image generation model, the lightweight version of Nano Banana 2",
        input_type: :text,
        output_type: :image,
        params: &%{prompt: &1, aspect_ratio: "16:9"},
        output: &Output.first_url/1
      },
      %__MODULE__{
        id: "krea-3",
        platform: Replicate,
        path: "krea/krea-3",
        name: "Krea 3",
        description: "Fast image generation and editing model from Krea",
        input_type: :text,
        output_type: :image,
        params: &%{prompt: &1, aspect_ratio: "16:9", resolution: "1k", thinking_mode: "fast"},
        output: &Output.first_url/1
      },
      %__MODULE__{
        id: "gpt-image-2.5-flare",
        platform: Replicate,
        path: "openai/gpt-image-2.5-flare",
        name: "GPT Image 2.5 Flare",
        description: "OpenAI's fastest image generation model",
        input_type: :text,
        output_type: :image,
        params:
          &%{
            prompt: &1,
            aspect_ratio: "16:9",
            quality: "low",
            moderation: "low",
            output_format: "jpeg"
          },
        output: &Output.first_url/1
      },
      %__MODULE__{
        id: "p-image",
        platform: Replicate,
        path: "prunaai/p-image",
        name: "P-Image",
        description: "Sub-second text-to-image model from Pruna AI",
        input_type: :text,
        output_type: :image,
        params: &%{prompt: &1, aspect_ratio: "16:9", disable_safety_checker: true},
        output: &Output.first_url/1
      },
      %__MODULE__{
        id: "gpt-5.6-luna-caption",
        platform: Replicate,
        path: "openai/gpt-5.6-luna",
        name: "GPT-5.6 Luna Caption",
        description: "Vivid description of the image, cut to fit a Vestaboard by DeepSeek V3.1",
        input_type: :image,
        output_type: :text,
        invoke: fn model, input, token ->
          vestaboard_caption(model, @describe_lens, "deepseek-ai/deepseek-v3.1", input, token)
        end
      },
      %__MODULE__{
        id: "claude-sonnet-5-uncanny",
        platform: Replicate,
        path: "anthropic/claude-sonnet-5",
        name: "Claude Sonnet 5 Uncanny",
        description: "What is odd or wrong about the image, cut to fit a Vestaboard by GPT-5.6 Luna",
        input_type: :image,
        output_type: :text,
        invoke: fn model, input, token ->
          vestaboard_caption(model, @uncanny_lens, "openai/gpt-5.6-luna", input, token)
        end
      },
      %__MODULE__{
        id: "gemini-3-flash-film-still",
        platform: Replicate,
        path: "google/gemini-3-flash",
        name: "Gemini 3 Flash Film Still",
        description: "The image as a frame from a film, cut to fit a Vestaboard by Claude Haiku 4.5",
        input_type: :image,
        output_type: :text,
        invoke: fn model, input, token ->
          vestaboard_caption(model, @film_still_lens, "anthropic/claude-4.5-haiku", input, token)
        end
      },
      %__MODULE__{
        id: "gemini-3.5-flash-critic",
        platform: Replicate,
        path: "google/gemini-3.5-flash",
        name: "Gemini 3.5 Flash Critic",
        description: "The image as an art critic sees it, cut to fit a Vestaboard by Llama 4 Maverick",
        input_type: :image,
        output_type: :text,
        invoke: fn model, input, token ->
          vestaboard_caption(model, @critic_lens, "meta/llama-4-maverick-instruct", input, token)
        end
      },
      %__MODULE__{
        id: "claude-4-sonnet",
        platform: Replicate,
        path: "anthropic/claude-4.5-sonnet",
        name: "Claude 4.5 Sonnet",
        input_type: :text,
        output_type: :text,
        params: &%{prompt: &1},
        output: &Output.text/1
      },
      %__MODULE__{
        id: "claude-4-sonnet-caption",
        platform: Replicate,
        path: "anthropic/claude-4.5-sonnet",
        name: "Claude 4.5 Sonnet Caption",
        input_type: :image,
        output_type: :text,
        params: &%{prompt: "describe this image in one sentence", image: &1, max_image_resolution: 0.5},
        output: &Output.text/1
      },
      %__MODULE__{
        id: "meta-llama-3-8b-instruct",
        platform: Replicate,
        path: "meta/meta-llama-3-8b-instruct",
        name: "LLaMa 8B Instruct",
        input_type: :text,
        output_type: :text,
        deprecated: true,
        params: &%{prompt: &1},
        output: &Output.text/1
      },
      %__MODULE__{
        id: "meta-llama-3-8b-songifier",
        platform: Replicate,
        path: "meta/meta-llama-3-8b-instruct",
        name: "LLaMa Songifier",
        input_type: :text,
        output_type: :text,
        deprecated: true,
        params: fn input ->
          %{
            prompt: """
            You are an expert music producer with skills in an extremely wide range of musical genres and styles.
            Interpret the following text as the design brief for a song, and reply with a one-sentence
            description of the song. You may include details like bpm, instrumentation, genre/feel, but
            reply only with the one-sentence description (do not say "Certainly", or "Here is the description"
            or anything other than the song description itself).

            #{input}
            """
          }
        end,
        output: &Output.text/1
      },
      %__MODULE__{
        id: "musicgen",
        platform: Replicate,
        path: "ardianfe/music-gen-fn-200e",
        name: "MusicGen",
        input_type: :text,
        output_type: :audio,
        deprecated: true,
        params: &%{prompt: &1, duration: 8, top_k: 1000, temperature: 1.1, output_format: "mp3"},
        output: &Output.first_url/1
      },
      %__MODULE__{
        id: "magnet",
        platform: Replicate,
        path: "lucataco/magnet",
        name: "MAGNeT",
        input_type: :text,
        output_type: :audio,
        params: &%{prompt: &1, model: "facebook/magnet-medium-10secs", variations: 1},
        output: &Output.first_url/1
      },
      %__MODULE__{
        id: "flux-music",
        platform: Replicate,
        path: "zsxkib/flux-music",
        name: "Flux Music",
        input_type: :text,
        output_type: :audio,
        params: &%{prompt: &1, model_version: "base", steps: 50},
        output: Output.key("wav")
      },
      %__MODULE__{
        id: "riffusion",
        platform: Replicate,
        path: "riffusion/riffusion",
        name: "Riffusion",
        input_type: :text,
        output_type: :audio,
        deprecated: true,
        params:
          &%{
            prompt_a: &1,
            alpha: 0,
            seed_image_id: Enum.random(~w(agile marim motorway og_beat vibes))
          },
        output: Output.key("audio")
      },
      %__MODULE__{
        id: "lyria-2",
        platform: Replicate,
        path: "google/lyria-2",
        name: "Lyria 2",
        description: "Lyria 2 is a music generation model that produces 48kHz stereo audio through text-based prompts",
        input_type: :text,
        output_type: :audio,
        params: &%{prompt: &1},
        output: &Output.first_url/1
      },
      %__MODULE__{
        id: "whisper",
        platform: Replicate,
        path: "openai/whisper",
        name: "Whisper",
        input_type: :audio,
        output_type: :text,
        # no_speech_threshold is set super high so that it tries to guess something
        params:
          &%{
            audio: &1,
            transcription: "plain text",
            condition_on_previous_text: false,
            no_speech_threshold: 1.0
          },
        output: Output.key("transcription")
      },
      %__MODULE__{
        id: "image-reproducer-i-flux",
        platform: Replicate,
        path: "black-forest-labs/flux-kontext-dev",
        name: "Image Reproducer I (Flux)",
        description: "Image generation/reproduction model that can create images from text or reproduce existing images",
        input_type: :text,
        output_type: :image,
        output: &Output.first_url/1,
        # reproduces an image URL, but the genesis prompt is text, which
        # flux-schnell turns into the first image
        invoke: fn model, input, token ->
          if String.starts_with?(input, "http") do
            call(
              model,
              %{
                prompt: "reproduce this image exactly",
                input_image: input,
                guidance: 2.5,
                num_inference_steps: 30,
                output_format: "png",
                aspect_ratio: "16:9"
              },
              token
            )
          else
            call(
              %{model | path: "black-forest-labs/flux-schnell"},
              flux_schnell_params(input),
              token
            )
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
        # passes the image URL through as text, so the network completes the cycle
        invoke: fn _model, input, _token -> {:ok, input, []} end
      }
    ] ++ dummy_models()
  end

  defp dummy_models do
    for {input_type, input_code} <- [text: "t", image: "i", audio: "a"],
        {output_type, output_code} <- [text: "t", image: "i", audio: "a"] do
      %__MODULE__{
        id: "dummy-#{input_code}2#{output_code}",
        platform: Dummy,
        path: "dummy/#{input_type}-to-#{output_type}",
        name: "Dummy #{dummy_type_name(input_type)}-to-#{dummy_type_name(output_type)}",
        input_type: input_type,
        output_type: output_type,
        description: "Dummy model for testing #{input_type}-to-#{output_type} transformations"
      }
    end
  end

  defp dummy_type_name(type), do: type |> Atom.to_string() |> String.capitalize()

  def all(filters) do
    Enum.filter(all(), fn model ->
      Enum.all?(filters, fn {field, value} -> Map.fetch!(model, field) == value end)
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

  defp flux_schnell_params(prompt),
    do: %{prompt: prompt, output_format: "png", aspect_ratio: "16:9", disable_safety_checker: true}

  # Describes `image` through `lens` with `captioner`, then has `condenser` (a
  # Replicate text model from another vendor) cut the description to fit a
  # Vestaboard, asking once more if it doesn't and trimming as a last resort.
  defp vestaboard_caption(captioner, lens, condenser, image, token) do
    captioner = %{captioner | output: &Output.text/1}

    with {:ok, description, described} <-
           call(captioner, captioner_input(captioner.path, lens, image), token),
         {:ok, caption, condensed} <- condense(condenser, description, @condense_prompt, token) do
      if Vestaboards.fits?(caption) do
        {:ok, caption, described ++ condensed}
      else
        prompt = @condense_prompt <> " Your last attempt was too long; cut harder."

        with {:ok, shorter, recondensed} <- condense(condenser, caption, prompt, token) do
          {:ok, Vestaboards.trim_to_fit(shorter), described ++ condensed ++ recondensed}
        end
      end
    end
  end

  defp condense(path, text, instructions, token) do
    condenser = %__MODULE__{
      id: path,
      path: path,
      name: path,
      platform: Replicate,
      input_type: :text,
      output_type: :text,
      output: &Output.text/1
    }

    with {:ok, caption, usage} <-
           call(condenser, condenser_input(path, instructions, text), token) do
      case Vestaboards.sanitise(caption) do
        "" -> {:error, "#{path} returned no caption"}
        caption -> {:ok, caption, usage}
      end
    end
  end

  defp captioner_input("google/" <> _, prompt, image), do: %{prompt: prompt, images: [image], thinking_level: "none"}

  defp captioner_input("openai/" <> _, prompt, image),
    do: %{prompt: prompt, image_input: [image], reasoning_effort: "none", verbosity: "low"}

  defp captioner_input("anthropic/" <> _, prompt, image),
    do: %{prompt: prompt, image: image, max_tokens: 1024, effort: "low", max_image_resolution: 0.5}

  defp condenser_input("anthropic/" <> _, system, text), do: %{prompt: text, system_prompt: system, max_tokens: 1024}

  defp condenser_input("openai/" <> _, system, text),
    do: %{prompt: text, system_prompt: system, reasoning_effort: "none", verbosity: "low"}

  defp condenser_input("meta/" <> _, system, text), do: %{prompt: text, system_prompt: system, max_tokens: 200}

  defp condenser_input("deepseek-ai/" <> _, system, text),
    do: %{prompt: "#{system}\n\nDescription:\n#{text}", max_tokens: 200, thinking: "None"}
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
