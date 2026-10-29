defmodule Panic.ModelInvokeTest do
  @moduledoc """
  `Panic.Model.invoke/3` with the platforms patched: what each model asks of
  its platform, and the output and usage it makes of the response.
  """
  use ExUnit.Case, async: true
  use Repatch.ExUnit

  alias Panic.Model
  alias Panic.Platforms.Replicate

  defp patch_replicate(respond) do
    test = self()

    Repatch.patch(Replicate, :invoke, fn model, input, _token ->
      send(test, {:called, model.path, input})
      {:ok, respond.(model.path), %{"platform" => "replicate", "path" => model.path}}
    end)
  end

  test "a single-call model sends its params and parses its output" do
    patch_replicate(fn _path -> ["https://example.com/a.png", "https://example.com/b.png"] end)

    assert {:ok, "https://example.com/a.png", [%{"path" => "google/imagen-4-fast"}]} =
             Model.invoke(Model.by_id!("imagen-4-fast"), "a cat", "token")

    assert_received {:called, "google/imagen-4-fast", %{prompt: "a cat", aspect_ratio: "16:9"}}
  end

  test "an output a model doesn't recognise is an error, not an output" do
    patch_replicate(fn _path -> %{"unexpected" => true} end)

    assert {:error, "Unexpected model output" <> _} =
             Model.invoke(Model.by_id!("imagen-4-fast"), "a cat", "token")
  end

  test "a Vestaboard captioner reports the usage of the captioner and the condenser" do
    patch_replicate(fn
      "google/gemini-3-flash" -> ["A long description ", "of a film still."]
      "anthropic/claude-4.5-haiku" -> "A short caption"
    end)

    assert {:ok, "A short caption", usage} =
             Model.invoke(
               Model.by_id!("gemini-3-flash-film-still"),
               "https://example.com/a.png",
               "token"
             )

    assert Enum.map(usage, & &1["path"]) == [
             "google/gemini-3-flash",
             "anthropic/claude-4.5-haiku"
           ]
  end

  test "a passthrough model makes no calls" do
    assert {:ok, "https://example.com/a.png", []} =
             Model.invoke(
               Model.by_id!("image-reproducer-ii-flux"),
               "https://example.com/a.png",
               "token"
             )
  end
end
