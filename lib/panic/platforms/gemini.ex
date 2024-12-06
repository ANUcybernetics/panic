defmodule Panic.Platforms.Gemini do
  @moduledoc false

  def invoke(%Panic.Model{path: model_path}, input, api_key) do
    request_body = %{
      contents: %{
        role: "USER",
        parts: [
          %{
            file_data: %{
              file_uri: input,
              mime_type: "audio/ogg"
            }
          },
          %{
            text:
              "Describe the audio file in two sentences. If it contains speech, please transcribe and return only the transcription. If it is instrumental music or sfx, describe what you hear."
          }
        ]
      }
    }

    [
      method: :post,
      url: "https://generativelanguage.googleapis.com/v1beta/models/#{model_path}:generateContent",
      json: request_body,
      params: [key: api_key]
    ]
    |> req_new()
    |> Req.request()
    |> case do
      {:ok, %Req.Response{status: 200, body: %{"candidates" => [%{"content" => %{"parts" => [%{"text" => text}]}} | _]}}} ->
        {:ok, text}

      {:ok, %Req.Response{body: %{"error" => %{"message" => message}}}} ->
        {:error, message}

      {:ok, %Req.Response{body: body}} ->
        {:error, "Unexpected response format: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp req_new(opts) do
    [
      receive_timeout: 10_000
    ]
    |> Keyword.merge(Application.get_env(:panic, :gemini_req_options, []))
    |> Keyword.merge(opts)
    |> Req.new()
  end
end
