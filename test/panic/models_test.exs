defmodule Panic.ModelsTest do
  use Panic.DataCase
  use ExUnitProperties
  alias Panic.Models

  describe "model helpers" do
    test "list all modules which conform to Model behaviour" do
      models = [
        Models.BLIP2,
        Models.StableDiffusion,
        Models.ClipCaptionReward,
        Models.GPT4o,
        Models.CogPromptParrot,
        Models.GPT4Turbo,
        Models.LLaVA,
        Models.ClipPrefixCaption,
        Models.SDXL,
        Models.GPT4
      ]

      # check that they're all in the list
      assert Models.list() |> MapSet.new() == MapSet.new(models)
    end

    test "list all Replicate models" do
      models = [
        Models.BLIP2,
        Models.StableDiffusion,
        Models.ClipCaptionReward,
        Models.CogPromptParrot,
        Models.LLaVA,
        Models.ClipPrefixCaption,
        Models.SDXL
      ]

      # check that they're all in the list
      assert Models.list(Panic.Platforms.Replicate) |> MapSet.new() == MapSet.new(models)
    end

    test "list all OpenAI models" do
      models = [
        Models.GPT4o,
        Models.GPT4,
        Models.GPT4Turbo
      ]

      # check that they're all in the list
      assert Models.list(Panic.Platforms.OpenAI) |> MapSet.new() == MapSet.new(models)
    end
  end

  describe "Replicate platform tests (mocked)" do
    alias Panic.Platforms.Replicate

    test "list models" do
      Req.Test.stub(Replicate, fn conn ->
        # this is the correct value at 2024-05-08, but it doesn't matter, we only test against the regex
        body = %{
          "latest_version" => %{
            "id" => "ac732df83cea7fff18b8472768c88ad041fa750ff7682a21affe81863cbe77e4"
          }
        }

        Req.Test.json(conn, body)
      end)

      version = Replicate.get_latest_model_version(Models.StableDiffusion)
      assert String.match?(version, ~r/^[a-f0-9]{64}$/)
    end

    test "invoke models" do
      # models for which we have canned responses
      models = [Models.GPT4o]

      canned_responses =
        "test/support/canned_responses/replicate.json"
        |> File.read!()
        |> Jason.decode!()

      for model <- models do
        model_key = to_string(model)

        Req.Test.stub(Replicate, fn conn ->
          body = get_in(canned_responses[model_key]["response"]["body"])

          Req.Test.json(conn, body)
        end)

        input = get_in(canned_responses[model_key]["input"])
        output = get_in(canned_responses[model_key]["output"])
        assert {:ok, ^output} = model.invoke(input)
      end
    end
  end
end
