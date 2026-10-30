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
    `predict_time` × the GPU's board power × its average fraction of that
    power × a data-centre PUE of 1.2 (between Google's fleet-wide 1.09 and the
    industry's 1.56). The fraction is 0.7 for models that keep the GPU busy
    (diffusion, parallel decoding), per Epoch AI's inference assumption, and
    0.45 for language and speech models decoding one request at a time, which
    are limited by memory bandwidth and draw well under board power (ML.ENERGY
    benchmark, <https://arxiv.org/abs/2505.06371>)
  - other models run on hardware nobody publishes, so their energy comes from
    published per-output measurements. An image takes 0.15 Wh from a few-step
    model (turbo or distilled, about 4 steps) and 1.0 Wh from a larger or
    undisclosed one: diffusion energy grows with steps, from about 0.45 Wh at
    10 steps to 2.1 Wh at 50 for Flux at 1024² on an A100 (Energy Scaling
    Laws for Diffusion Models, <https://arxiv.org/abs/2511.17031>), and MIT
    Technology Review measured 0.63 Wh for SD3 Medium with overheads
    (<https://www.technologyreview.com/2025/05/20/1116327/ai-energy-usage-climate-footprint-big-tech/>).
    Frontier language models' per-token rates fit Epoch AI's estimate of about
    0.3 Wh for a 500-token chat reply and 2.5 Wh for one with a 10,000-token
    prompt (<https://epoch.ai/gradient-updates/how-much-energy-does-chatgpt-use>),
    which matches Google's 0.24 Wh median Gemini prompt
    (<https://arxiv.org/abs/2508.15734>); small ones (Haiku, Flash, Llama 4's
    17B-active models) use about 0.3 of that, a judgement from MIT Technology
    Review's Llama 3.1 8B measurement

  A call to a model without a price here estimates as `nil`, as does any
  invocation that made one; `Panic.Engine.FootprintTest` checks every model in
  use has one.
  """

  @pue 1.2

  # average fraction of board power drawn while computing and while decoding
  @computing 0.7
  @decoding 0.45

  # USD per second and board power in watts (replicate.com/pricing, nvidia.com)
  @gpus %{
    t4: {0.000225, 70},
    l40s: {0.000975, 350},
    a100: {0.0014, 400},
    h100: {0.001525, 700}
  }

  # Wh per image
  @few_step_image 0.15
  @large_image 1.0

  # Wh per input and output token
  @frontier_tokens {0.0002, 0.0006}
  @small_tokens {0.00006, 0.0002}

  # Lyria 2 makes 30 s clips, billed at $0.002/s; energy is MusicGen Large's
  # 0.057 Wh per generated second (TTM-Bench, https://arxiv.org/abs/2609.18585)
  @lyria_clip {0.06, 30 * 0.057 * @pue}

  # Replicate's prices, from each model's page; megapixel-priced models
  # (flux-2-klein-4b, z-image-turbo) are priced per call at one megapixel
  @replicate %{
    "zsxkib/molmo-7b" => {:gpu, :l40s, @decoding},
    "lucataco/qwen2-vl-7b-instruct" => {:gpu, :l40s, @decoding},
    "lucataco/magnet" => {:gpu, :l40s, @computing},
    "zsxkib/flux-music" => {:gpu, :l40s, @computing},
    "openai/whisper" => {:gpu, :t4, @decoding},
    "stability-ai/stable-diffusion-3.5-large-turbo" => {:image, 0.04, @few_step_image},
    "google/imagen-4-fast" => {:image, 0.02, @few_step_image},
    "luma/photon-flash" => {:image, 0.01, @few_step_image},
    "black-forest-labs/flux-2-klein-4b" => {:image, 0.001, @few_step_image},
    "black-forest-labs/flux-schnell" => {:image, 0.003, @few_step_image},
    "black-forest-labs/flux-kontext-dev" => {:image, 0.025, @large_image},
    "bytedance/seedream-4.5" => {:image, 0.04, @large_image},
    "prunaai/z-image-turbo" => {:image, 0.005, @few_step_image},
    "prunaai/p-image" => {:image, 0.005, @few_step_image},
    "ideogram-ai/ideogram-v3-turbo" => {:image, 0.03, @large_image},
    "google/nano-banana-2-lite" => {:image, 0.034, @large_image},
    "krea/krea-3" => {:image, 0.03, @large_image},
    "openai/gpt-image-2.5-flare" => {:image, 0.012, @large_image},
    "meta/llama-4-scout-instruct" => {:tokens, 0.17, 0.65, @small_tokens},
    "meta/llama-4-maverick-instruct" => {:tokens, 0.25, 0.95, @small_tokens},
    "openai/gpt-5.6-luna" => {:tokens, 1.0, 6.0, @frontier_tokens},
    "anthropic/claude-sonnet-5" => {:tokens, 2.0, 10.0, @frontier_tokens},
    "anthropic/claude-4.5-sonnet" => {:tokens, 3.0, 15.0, @frontier_tokens},
    "anthropic/claude-4.5-haiku" => {:tokens, 1.0, 5.0, @small_tokens},
    "google/gemini-3-flash" => {:tokens, 0.5, 3.0, @small_tokens},
    "google/gemini-3.5-flash" => {:tokens, 1.5, 9.0, @small_tokens},
    "deepseek-ai/deepseek-v3.1" => {:tokens, 0.672, 2.016, @frontier_tokens},
    "google/lyria-2" => {:clip, @lyria_clip}
  }

  # the platforms' own APIs; Gemini's input price is its audio rate, since
  # the Gemini models only describe audio
  @direct %{
    {"openai", "gpt-5.6-luna"} => {:tokens, 0.2, 1.2, @frontier_tokens},
    {"gemini", "gemini-2.5-flash"} => {:tokens, 1.0, 2.5, @small_tokens},
    {"gemini", "gemini-2.5-pro"} => {:tokens, 1.25, 10.0, @frontier_tokens}
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

  defp apply_rate({:gpu, gpu, utilisation}, %{"predict_time" => seconds}) when is_number(seconds) do
    {usd_per_second, watts} = Map.fetch!(@gpus, gpu)

    %{
      cost_usd: seconds * usd_per_second,
      energy_wh: seconds * watts * utilisation * @pue / 3600
    }
  end

  defp apply_rate({:image, usd, wh}, usage) do
    images = Map.get(usage, "image_output_count", 1)
    %{cost_usd: images * usd, energy_wh: images * wh}
  end

  defp apply_rate({:tokens, usd_per_m_input, usd_per_m_output, {input_wh, output_wh}}, %{
         "input_token_count" => input,
         "output_token_count" => output
       })
       when is_integer(input) and is_integer(output) do
    %{
      cost_usd: (input * usd_per_m_input + output * usd_per_m_output) / 1_000_000,
      energy_wh: input * input_wh + output * output_wh
    }
  end

  defp apply_rate({:clip, {usd, wh}}, _usage), do: %{cost_usd: usd, energy_wh: wh}

  # an unpriced model, or a priced one that didn't report what it's billed on
  defp apply_rate(_rate, _usage), do: %{cost_usd: nil, energy_wh: nil}
end
