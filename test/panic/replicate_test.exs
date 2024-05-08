defmodule Panic.ReplicateTest do
  use Panic.DataCase
  alias Panic.Platforms.Replicate
  alias Panic.Models

  describe "test the Replicate AI provider" do
    test "list models" do
      Req.Test.stub(Panic.Platforms.Replicate, fn conn ->
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
  end
end
