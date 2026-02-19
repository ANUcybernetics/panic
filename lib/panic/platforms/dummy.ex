defmodule Panic.Platforms.Dummy do
  @moduledoc """
  Dummy platform module for testing that returns deterministic outputs without making API calls

  Supports all input/output type combinations (text, image, audio) for comprehensive testing
  """

  @doc """
  Invoke a dummy model with deterministic output for testing.

  The dummy platform doesn't make any external API calls and returns
  predictable outputs based on the input and output types.
  """
  def invoke(%Panic.Model{input_type: input_type, output_type: output_type}, input, _token) do
    generate_output(input_type, output_type, input)
  end

  @doc """
  Invoke with controlled error behaviour for testing retry logic.

  Accepts an `error_spec` parameter:
  - `{:fail_n_times, n}` --- uses process dictionary counter to fail `n` times then succeed
  - `:always_fail` --- always returns `{:error, ...}`
  """
  def invoke_with_errors(%Panic.Model{} = model, input, token, error_spec) do
    case error_spec do
      {:fail_n_times, n} ->
        count = Process.get(:dummy_error_count, 0)

        if count < n do
          Process.put(:dummy_error_count, count + 1)
          {:error, "simulated transient error (attempt #{count + 1})"}
        else
          invoke(model, input, token)
        end

      :always_fail ->
        {:error, "simulated permanent error"}
    end
  end

  defp generate_output(:text, :text, input) when is_binary(input) do
    # Simple transformation: reverse the input and add a prefix
    output = "DUMMY_TEXT: #{String.reverse(input)}"
    {:ok, output}
  end

  defp generate_output(:text, :image, input) when is_binary(input) do
    # Return a fake image URL based on the input
    hash = :md5 |> :crypto.hash(input) |> Base.encode16() |> String.downcase()
    {:ok, "https://dummy-images.test/#{hash}.png"}
  end

  defp generate_output(:text, :audio, input) when is_binary(input) do
    # Return a fake audio URL based on the input
    hash = :md5 |> :crypto.hash(input) |> Base.encode16() |> String.downcase()
    {:ok, "https://dummy-audio.test/#{hash}.ogg"}
  end

  defp generate_output(:image, :text, input) when is_binary(input) do
    # Extract a "description" from the image URL
    if String.contains?(input, "dummy-images.test") do
      # If it's already a dummy image, extract the hash
      hash = input |> String.split("/") |> List.last() |> String.replace(".png", "")
      {:ok, "DUMMY_CAPTION: Image with hash #{hash}"}
    else
      # For any other image URL, generate a deterministic caption
      hash =
        :md5 |> :crypto.hash(input) |> Base.encode16() |> String.downcase() |> String.slice(0..7)

      {:ok, "DUMMY_CAPTION: A descriptive caption for image #{hash}"}
    end
  end

  defp generate_output(:image, :image, input) when is_binary(input) do
    # Transform one image URL to another
    hash = :md5 |> :crypto.hash(input <> "_transformed") |> Base.encode16() |> String.downcase()
    {:ok, "https://dummy-images.test/transformed_#{hash}.png"}
  end

  defp generate_output(:image, :audio, input) when is_binary(input) do
    # Generate audio from image
    hash = :md5 |> :crypto.hash(input <> "_audio") |> Base.encode16() |> String.downcase()
    {:ok, "https://dummy-audio.test/from_image_#{hash}.ogg"}
  end

  defp generate_output(:audio, :text, %{audio_file: audio_file, prompt: prompt}) do
    # Handle Gemini-style input with prompt
    hash =
      :md5
      |> :crypto.hash(audio_file <> prompt)
      |> Base.encode16()
      |> String.downcase()
      |> String.slice(0..7)

    {:ok, "DUMMY_DESCRIPTION: #{prompt} - Audio #{hash}"}
  end

  defp generate_output(:audio, :text, %{audio_file: audio_file}) do
    # Handle map with just audio_file key
    hash =
      :md5
      |> :crypto.hash(audio_file)
      |> Base.encode16()
      |> String.downcase()
      |> String.slice(0..7)

    {:ok, "DUMMY_TRANSCRIPT: Audio content from #{hash}"}
  end

  defp generate_output(:audio, :text, input) when is_binary(input) do
    # Handle direct audio URL input
    hash =
      :md5 |> :crypto.hash(input) |> Base.encode16() |> String.downcase() |> String.slice(0..7)

    {:ok, "DUMMY_TRANSCRIPT: Audio content from #{hash}"}
  end

  defp generate_output(:audio, :image, input) when is_binary(input) do
    # Generate image from audio
    hash = :md5 |> :crypto.hash(input <> "_image") |> Base.encode16() |> String.downcase()
    {:ok, "https://dummy-images.test/from_audio_#{hash}.png"}
  end

  defp generate_output(:audio, :audio, input) when is_binary(input) do
    # Transform one audio to another
    hash = :md5 |> :crypto.hash(input <> "_transformed") |> Base.encode16() |> String.downcase()
    {:ok, "https://dummy-audio.test/transformed_#{hash}.ogg"}
  end

  defp generate_output(input_type, output_type, _input) do
    {:error, "Unsupported dummy conversion from #{input_type} to #{output_type}"}
  end
end
