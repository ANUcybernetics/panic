defmodule Panic.Platforms.Gemini do
  @moduledoc false

  def invoke(%Panic.Model{path: model_path}, input, api_key) do
    with {:ok, audio_data} <- download_to_base64(input) do
      request_body = %{
        contents: %{
          role: "USER",
          parts: [
            %{
              inline_data: %{
                mime_type: "audio/ogg",
                data: audio_data
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
        {:ok,
         %Req.Response{status: 200, body: %{"candidates" => [%{"content" => %{"parts" => [%{"text" => text}]}} | _]}}} ->
          {:ok, text}

        {:ok, %Req.Response{body: %{"error" => %{"message" => message}}}} ->
          {:error, message}

        {:ok, %Req.Response{body: body}} ->
          {:error, "Unexpected response format: #{inspect(body)}"}

        {:error, reason} ->
          {:error, reason}
      end
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

  defp download_to_base64(url) do
    case Req.get(url: url) do
      {:ok, %Req.Response{body: body, status: status}} when status in 200..299 ->
        {:ok, Base.encode64(body)}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
