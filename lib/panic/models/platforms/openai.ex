defmodule Panic.Models.Platforms.OpenAI do
  @url "https://api.openai.com/v1"
  @temperature 0.7
  @max_response_length 50
  # @recv_timeout 10_000

  def list_engines(tokens) do
    Finch.build(:get, @url <> "/engines", headers(tokens))
    |> Finch.request(Panic.Finch)
    |> case do
      {:ok, %Finch.Response{body: response_body, status: 200}} ->
        %{"data" => data} = Jason.decode!(response_body)
        data

      {:error, reason} ->
        {:error, reason}
    end
  end

  def create(model_id, prompt, tokens) do
    request(model_id, prompt, tokens)
    |> Finch.request(Panic.Finch)
    |> case do
      {:ok, %Finch.Response{body: response_body, status: 200}} ->
        case Jason.decode!(response_body) do
          %{"choices" => [%{"text" => ""} | _choices]} -> {:error, :blank_output}
          %{"choices" => [%{"text" => text} | _choices]} -> {:ok, text}
          %{"choices" => [%{"message" => %{"content" => text}} | _choices]} -> {:ok, text}
        end
    end
  end

  defp request("openai:gpt-3.5-turbo", prompt, tokens) do
    request_body = %{
      model: "gpt-3.5-turbo",
      messages: [
        %{
          "role" => "system",
          "content" =>
            "You are one component of a larger AI artwork system. Your job is to describe what you see."
        },
        %{"role" => "user", "content" => prompt}
      ]
    }

    Finch.build(
      :post,
      "#{@url}/chat/completions",
      headers(tokens),
      Jason.encode!(request_body)
    )
  end

  defp request(model_id, prompt, tokens) do
    request_body = %{
      prompt: prompt,
      max_tokens: @max_response_length,
      temperature: @temperature
    }

    Finch.build(
      :post,
      "#{@url}/engines/#{model_id |> Panic.Platforms.model_info() |> Map.get(:path)}/completions",
      headers(tokens),
      Jason.encode!(request_body)
    )
  end

  defp headers(%{"OpenAI" => token}) do
    %{
      "Authorization" => "Bearer #{token}",
      "Content-Type" => "application/json"
    }
  end
end
