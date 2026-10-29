defmodule Panic.Engine.FootprintTest do
  use ExUnit.Case, async: true

  alias Panic.Engine.Footprint
  alias Panic.Model

  # models the Vestaboard captioners and image reproducer call besides their own
  @helper_paths ~w(deepseek-ai/deepseek-v3.1 openai/gpt-5.6-luna anthropic/claude-4.5-haiku
                   meta/llama-4-maverick-instruct black-forest-labs/flux-schnell)

  test "every model in use has a price" do
    unpriced =
      for model <- Model.all(deprecated: false),
          platform = model.platform |> Module.split() |> List.last() |> String.downcase(),
          not Footprint.priced?(platform, model.path),
          do: model.id

    assert unpriced == []
    assert Enum.all?(@helper_paths, &Footprint.priced?("replicate", &1))
  end

  test "a GPU-time model costs its hardware's rate and uses its board power" do
    # 100 s on an L40S: $0.000975/s, and 350 W × 0.7 × PUE 1.2
    assert %{cost_usd: cost, energy_wh: energy} =
             Footprint.estimate([
               %{"platform" => "replicate", "path" => "zsxkib/molmo-7b", "predict_time" => 100}
             ])

    assert_in_delta cost, 0.0975, 1.0e-9
    assert_in_delta energy, 8.1667, 1.0e-4
  end

  test "an image model costs its price per image" do
    usage = %{
      "platform" => "replicate",
      "path" => "google/imagen-4-fast",
      "image_output_count" => 2
    }

    assert %{cost_usd: cost, energy_wh: energy} = Footprint.estimate([usage])
    assert_in_delta cost, 0.04, 1.0e-9
    assert_in_delta energy, 5.8, 1.0e-9
  end

  test "a language model costs its price per token, on Replicate or directly" do
    usage = %{"input_token_count" => 1_000_000, "output_token_count" => 100_000}

    assert %{cost_usd: replicate} =
             Footprint.estimate([
               Map.merge(usage, %{"platform" => "replicate", "path" => "openai/gpt-5.6-luna"})
             ])

    assert %{cost_usd: direct} =
             Footprint.estimate([
               Map.merge(usage, %{"platform" => "openai", "path" => "gpt-5.6-luna"})
             ])

    assert_in_delta replicate, 1.6, 1.0e-9
    assert_in_delta direct, 0.32, 1.0e-9
  end

  test "sums the calls of a multi-call model" do
    describe = %{"platform" => "replicate", "path" => "google/gemini-3-flash"}
    condense = %{"platform" => "replicate", "path" => "anthropic/claude-4.5-haiku"}
    tokens = %{"input_token_count" => 1000, "output_token_count" => 100}

    single = Footprint.estimate([Map.merge(describe, tokens)])
    both = Footprint.estimate([Map.merge(describe, tokens), Map.merge(condense, tokens)])

    assert both.cost_usd > single.cost_usd
    assert both.energy_wh == 2 * single.energy_wh
  end

  test "can't estimate an unpriced model, or one that didn't report what it's billed on" do
    unpriced = %{"platform" => "replicate", "path" => "someone/unknown", "predict_time" => 1}
    no_time = %{"platform" => "replicate", "path" => "zsxkib/molmo-7b"}
    priced = %{"platform" => "replicate", "path" => "google/imagen-4-fast"}

    assert Footprint.estimate([priced, unpriced]) == %{cost_usd: nil, energy_wh: nil}
    assert Footprint.estimate([no_time]) == %{cost_usd: nil, energy_wh: nil}
  end

  test "dummy models and passthroughs cost nothing" do
    assert Footprint.estimate([%{"platform" => "dummy", "path" => "dummy/text-to-text"}]) ==
             %{cost_usd: 0.0, energy_wh: 0.0}

    assert Footprint.estimate([]) == %{cost_usd: 0.0, energy_wh: 0.0}
  end
end
