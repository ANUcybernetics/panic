defmodule Panic.Platforms.OpenAI do
  # TODO perhaps make these defaults, but also pull from the Model struct?
  @moduledoc false
  @temperature 1.0
  @max_completion_tokens 150

  def list_engines(token) do
    [url: "/engines", auth: {:bearer, token}]
    |> req_new()
    |> Req.request()
    |> case do
      {:ok, %Req.Response{body: body, status: 200}} ->
        %{"data" => data} = body
        data

      {:ok, %Req.Response{body: %{"error" => %{"message" => message}}}} ->
        {:error, message}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def invoke(%Panic.Model{path: path}, input, token) do
    request_body = %{
      model: path,
      messages: [
        %{
          "role" => "system",
          "content" =>
            "You are one component of a larger AI artwork system. When given input, always respond with a creative interpretation, description, or continuation. Never leave a response empty."
        },
        %{"role" => "user", "content" => input}
      ],
      temperature: @temperature,
      max_completion_tokens: @max_completion_tokens
    }

    [method: :post, url: "/chat/completions", json: request_body, auth: {:bearer, token}]
    |> req_new()
    |> Req.request()
    |> case do
      {:ok, %Req.Response{body: body, status: 200}} ->
        case body do
          %{"choices" => [%{"text" => ""}]} -> {:error, :blank_output}
          %{"choices" => [%{"text" => text}]} -> {:ok, text}
          %{"choices" => [%{"message" => %{"content" => text}}]} -> {:ok, text}
          _ -> {:error, :unexpected_response_format}
        end

      {:ok, %Req.Response{body: %{"error" => %{"message" => message}}}} ->
        {:error, message}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp req_new(opts) do
    [
      base_url: "https://api.openai.com/v1",
      receive_timeout: 10_000
    ]
    |> Keyword.merge(Application.get_env(:panic, :openai_req_options, []))
    |> Keyword.merge(opts)
    |> Req.new()
  end
end
