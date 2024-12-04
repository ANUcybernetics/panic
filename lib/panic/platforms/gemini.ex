defmodule Panic.Platforms.Gemini do
  @moduledoc false

  # Default generation config values
  @temperature 0.7
  @max_tokens 50

  def list_engines(_token) do
    # Gemini doesn't have a list_engines equivalent, so we'll return a static list
    # of the available models
    [
      %{
        "id" => "gemini-1.5-pro",
        "name" => "Gemini 1.5 Pro",
        "description" => "Most capable Gemini model for text, code, and analysis"
      },
      %{
        "id" => "gemini-1.5-pro-latest",
        "name" => "Gemini 1.5 Pro Latest",
        "description" => "Latest version of Gemini 1.5 Pro"
      },
      %{
        "id" => "gemini-1.5-flash",
        "name" => "Gemini 1.5 Flash",
        "description" => "Optimized for faster responses"
      }
    ]
  end

  def invoke(%Panic.Model{path: model_path}, input, api_key) do
    request_body = %{
      contents: [
        %{
          parts: [
            %{text: input}
          ]
        }
      ],
      generationConfig: %{
        temperature: @temperature,
        maxOutputTokens: @max_tokens
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
