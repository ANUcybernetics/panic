defmodule Panic.Models.Platforms.HuggingFace do
  @url "https://api-inference.huggingface.co/models"

  def create_and_wait(model, input_params) do
    url = "#{@url}/#{model}"

    {:ok, request_body} = Jason.encode(input_params)

    case HTTPoison.post(url, request_body, headers(), hackney: [pool: :default]) do
      {:ok, %HTTPoison.Response{status_code: 503}} ->
        create_and_wait(model, input_params)

      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        response_body
    end
  end

  def create("facebook/fastspeech2-en-ljspeech" = model, prompt) do
    filename = "priv/static/model_outputs/#{Slug.slugify(prompt)}.mp3"
    File.write(filename, create_and_wait(model, prompt))
    filename
  end

  defp headers do
    api_token = Application.fetch_env!(:panic, :huggingface_api_token)

    %{
      "Authorization" => "Bearer #{api_token}",
      "Content-Type" => "application/json"
    }
  end
end
