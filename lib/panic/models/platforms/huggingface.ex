defmodule Panic.Models.Platforms.HuggingFace do
  @url "https://api-inference.huggingface.co/models"
  @local_file_path "priv/static/model_outputs"

  def create_and_wait(model, data) do
    url = "#{@url}/#{model}"

    case HTTPoison.post(url, data, headers(), hackney: [pool: :default]) do
      {:ok, %HTTPoison.Response{status_code: 503}} ->
        create_and_wait(model, data)

      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        response_body
    end
  end

  def create("facebook/fastspeech2-en-ljspeech" = model, prompt) do
    audio_file = "#{@local_file_path}/#{Slug.slugify(prompt)}.mp3"
    :ok = File.write(audio_file, create_and_wait(model, prompt))
    audio_file
  end

  def create("facebook/wav2vec2-base-960h" = model, audio_file) do
    input_file = sox_convert_file(audio_file, "flac", 16000)
    {:ok, data} = File.read(input_file)
    {:ok, %{"text" => text}} = Jason.decode(create_and_wait(model, data))
    text
  end

  defp headers do
    api_token = Application.fetch_env!(:panic, :huggingface_api_token)

    %{
      "Authorization" => "Bearer #{api_token}",
      "Content-Type" => "application/json"
    }
  end

  def sox_convert_file(input_file, output_extension, sample_rate) do
    output_file = "#{Path.rootname(input_file)}.#{output_extension}"
    System.cmd("sox", [input_file, "#{output_file}", "rate", to_string(sample_rate)])
    output_file
  end
end
