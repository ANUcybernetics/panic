defmodule Panic.Models.Platforms.OpenAI do
  @url "https://api.openai.com/v1/engines"
  @temperature 0.7
  @max_response_length 50
  @recv_timeout 30_000

  def list_engines() do
    case HTTPoison.get(@url, headers(), recv_timeout: @recv_timeout) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, %{"data" => data}} = Jason.decode(response_body)

        data

      {:error, reason} ->
        {:error, reason}
    end
  end

  def create("text-davinci-002" = model, prompt) do
    url = "#{@url}/#{model}/completions"

    {:ok, request_body} =
      Jason.encode(%{
        prompt: "Reword the following sentence using more descriptive language:\n\n" <> prompt,
        max_tokens: @max_response_length,
        temperature: @temperature
      })

    case HTTPoison.post(url, request_body, headers(), recv_timeout: @recv_timeout) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, %{"choices" => [%{"text" => text} | _choices]}} = Jason.decode(response_body)

        if text == "", do: "GPT-3 could not complete the prompt.", else: String.downcase(text)
    end
  end

  defp headers do
    api_token = Application.fetch_env!(:panic, :openai_api_token)

    %{
      "Authorization" => "Bearer #{api_token}",
      "Content-Type" => "application/json"
    }
  end
end
