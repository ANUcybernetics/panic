defmodule Panic.ModelsTest do
  use Panic.DataCase
  use ExUnitProperties

  describe "model helpers" do
    test "list all modules which conform to Model behaviour" do
      models = [
        Panic.Models.BLIP2,
        Panic.Models.StableDiffusion,
        Panic.Models.ClipCaptionReward,
        Panic.Models.GPT4o,
        Panic.Models.CogPromptParrot,
        Panic.Models.GPT4Turbo,
        Panic.Models.LLaVA,
        Panic.Models.ClipPrefixCaption,
        Panic.Models.Vicuna13B,
        Panic.Models.SDXL,
        Panic.Models.GPT4
      ]

      # check that they're all in the list
      assert Panic.Models.list() |> MapSet.new() == MapSet.new(models)
    end
  end
end
