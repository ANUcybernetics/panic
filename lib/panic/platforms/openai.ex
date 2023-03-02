defmodule Panic.Platforms.OpenAI do
  @url "https://api.openai.com/v1/engines"
  @temperature 0.7
  @max_response_length 50
  # @recv_timeout 10_000

  def list_engines(tokens) do
    Finch.build(:get, @url, headers(tokens))
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
    request_body = %{
      prompt: prompt,
      max_tokens: @max_response_length,
      temperature: @temperature
    }

    Finch.build(
      :post,
      "#{@url}/#{model_id |> Panic.Platforms.model_info() |> Map.get(:path)}/completions",
      headers(tokens),
      Jason.encode!(request_body)
    )
    |> Finch.request(Panic.Finch)
    |> case do
      {:ok, %Finch.Response{body: response_body, status: 200}} ->
        %{"choices" => [%{"text" => text} | _choices]} = Jason.decode!(response_body)

        if text == "" do
          {:error, :blank_output}
        else
          {:ok, text}
        end
    end
  end

  defp headers(%{"OpenAI" => token}) do
    %{
      "Authorization" => "Bearer #{token}",
      "Content-Type" => "application/json"
    }
  end
end
