defmodule Panic.Engine.Footprint do
  @moduledoc """
  Estimates the cost (US dollars) and energy (watt-hours) of the platform calls
  behind an invocation, from the usage each call reported (see
  `Panic.Model.invoke/3`). Both are ballpark figures, so displays should
  present them as estimates.

  Cost is what the platform bills, from its published prices (read
  2026-10-29): per second of GPU time on the model's hardware, per output
  image, per call, or per million input and output tokens.

  No platform reports energy, so it's estimated two ways:

  - a model billed by GPU time runs on known hardware, so its energy is
    `predict_time` × the GPU's board power × 0.7 (Epoch AI's assumed
    average fraction of peak power under inference) × a data-centre PUE of
    1.2 (between Google's fleet-wide 1.09 and the industry's 1.56)
  - other models run on hardware nobody publishes, so their energy comes from
    published per-output measurements: 2.9 Wh per image (the image
    generation mean in Luccioni, Jernite & Strubell 2024, "Power Hungry
    Processing", <https://arxiv.org/abs/2311.16863>), and per token from Epoch
    AI's estimate of about 0.3 Wh for a 500-token chat reply and 2.5 Wh for one
    with a 10,000-token prompt
    (<https://epoch.ai/gradient-updates/how-much-energy-does-chatgpt-use>)

  A call to a model without a price here estimates as `nil`, as does any
  invocation that made one; `Panic.Engine.FootprintTest` checks every model in
  use has one.
  """

  @utilisation 0.7
  @pue 1.2

  # USD per second and board power in watts (replicate.com/pricing, nvidia.com)
  @gpus %{
    t4: {0.000225, 70},
    l40s: {0.000975, 350},
    a100: {0.0014, 400},
    h100: {0.001525, 700}
  }

  @image_wh 2.9
  @input_token_wh 0.0002
  @output_token_wh 0.0006

  # Lyria 2 makes 30 s clips, billed at $0.002/s; energy is MusicGen Large's
  # 0.057 Wh per generated second (TTM-Bench, https://arxiv.org/abs/2609.18585)
  @lyria_clip {0.06, 30 * 0.057 * @pue}

  # Replicate's prices, from each model's page; megapixel-priced models
  # (flux-2-klein-4b, z-image-turbo) are priced per call at one megapixel
  @replicate %{
    "zsxkib/molmo-7b" => {:gpu, :l40s},
    "lucataco/qwen2-vl-7b-instruct" => {:gpu, :l40s},
    "lucataco/magnet" => {:gpu, :l40s},
    "zsxkib/flux-music" => {:gpu, :l40s},
    "openai/whisper" => {:gpu, :t4},
    "stability-ai/stable-diffusion-3.5-large-turbo" => {:image, 0.04},
    "google/imagen-4-fast" => {:image, 0.02},
    "luma/photon-flash" => {:image, 0.01},
    "black-forest-labs/flux-2-klein-4b" => {:image, 0.001},
    "black-forest-labs/flux-schnell" => {:image, 0.003},
    "black-forest-labs/flux-kontext-dev" => {:image, 0.025},
    "bytedance/seedream-4.5" => {:image, 0.04},
    "prunaai/z-image-turbo" => {:image, 0.005},
    "prunaai/p-image" => {:image, 0.005},
    "ideogram-ai/ideogram-v3-turbo" => {:image, 0.03},
    "google/nano-banana-2-lite" => {:image, 0.034},
    "krea/krea-3" => {:image, 0.03},
    "openai/gpt-image-2.5-flare" => {:image, 0.012},
    "meta/llama-4-scout-instruct" => {:tokens, 0.17, 0.65},
    "meta/llama-4-maverick-instruct" => {:tokens, 0.25, 0.95},
    "openai/gpt-5.6-luna" => {:tokens, 1.0, 6.0},
    "anthropic/claude-sonnet-5" => {:tokens, 2.0, 10.0},
    "anthropic/claude-4.5-sonnet" => {:tokens, 3.0, 15.0},
    "anthropic/claude-4.5-haiku" => {:tokens, 1.0, 5.0},
    "google/gemini-3-flash" => {:tokens, 0.5, 3.0},
    "google/gemini-3.5-flash" => {:tokens, 1.5, 9.0},
    "deepseek-ai/deepseek-v3.1" => {:tokens, 0.672, 2.016},
    "google/lyria-2" => {:clip, @lyria_clip}
  }

  # the platforms' own APIs; Gemini's input price is its audio rate, since
  # the Gemini models only describe audio
  @direct %{
    {"openai", "gpt-5.6-luna"} => {:tokens, 0.2, 1.2},
    {"gemini", "gemini-2.5-flash"} => {:tokens, 1.0, 2.5},
    {"gemini", "gemini-2.5-pro"} => {:tokens, 1.25, 10.0}
  }

  @type estimate :: %{cost_usd: float() | nil, energy_wh: float() | nil}

  @doc """
  The total estimate for a list of usages, `nil` (for each figure) if any of
  them can't be estimated.
  """
  @spec estimate([Panic.Model.usage()]) :: estimate()
  def estimate(usages) do
    estimates = Enum.map(usages, &estimate_call/1)

    %{
      cost_usd: sum(estimates, :cost_usd),
      energy_wh: sum(estimates, :energy_wh)
    }
  end

  @doc "Whether calls to the model at `path` on `platform` (\"replicate\", ...) can be estimated."
  def priced?(platform, path), do: platform == "dummy" or rate(%{"platform" => platform, "path" => path}) != nil

  defp sum(estimates, key) do
    values = Enum.map(estimates, & &1[key])
    if Enum.any?(values, &is_nil/1), do: nil, else: Enum.sum(values) * 1.0
  end

  defp estimate_call(%{"platform" => "dummy"}), do: %{cost_usd: 0.0, energy_wh: 0.0}
  defp estimate_call(usage), do: usage |> rate() |> apply_rate(usage)

  defp rate(%{"platform" => "replicate", "path" => path}), do: @replicate[path]
  defp rate(%{"platform" => platform, "path" => path}), do: @direct[{platform, path}]

  defp apply_rate({:gpu, gpu}, %{"predict_time" => seconds}) when is_number(seconds) do
    {usd_per_second, watts} = Map.fetch!(@gpus, gpu)

    %{
      cost_usd: seconds * usd_per_second,
      energy_wh: seconds * watts * @utilisation * @pue / 3600
    }
  end

  defp apply_rate({:image, usd}, usage) do
    images = Map.get(usage, "image_output_count", 1)
    %{cost_usd: images * usd, energy_wh: images * @image_wh}
  end

  defp apply_rate({:tokens, usd_per_m_input, usd_per_m_output}, %{
         "input_token_count" => input,
         "output_token_count" => output
       })
       when is_integer(input) and is_integer(output) do
    %{
      cost_usd: (input * usd_per_m_input + output * usd_per_m_output) / 1_000_000,
      energy_wh: input * @input_token_wh + output * @output_token_wh
    }
  end

  defp apply_rate({:clip, {usd, wh}}, _usage), do: %{cost_usd: usd, energy_wh: wh}

  # an unpriced model, or a priced one that didn't report what it's billed on
  defp apply_rate(_rate, _usage), do: %{cost_usd: nil, energy_wh: nil}
end
