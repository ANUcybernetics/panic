defmodule Panic.Platforms.OpenAI do
  @temperature 0.7
  @max_tokens 50

  def list_engines do
    req_new(url: "/engines")
    |> Req.request()
    |> case do
      {:ok, %Req.Response{body: body, status: 200}} ->
        %{"data" => data} = body
        data

      {:error, reason} ->
        {:error, reason}
    end
  end

  def create(model, input) do
    request(model, input)
    |> Req.request()
    |> case do
      {:ok, %Req.Response{body: body, status: 200}} ->
        case body do
          %{"choices" => [%{"text" => ""}]} -> {:error, :blank_output}
          %{"choices" => [%{"text" => text}]} -> {:ok, text}
          %{"choices" => [%{"message" => %{"content" => text}}]} -> {:ok, text}
          _ -> {:error, :unexpected_response_format}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp request(model, input) do
    request_body = %{
      model: model.info(:id),
      messages: [
        # %{
        #   "role" => "system",
        #   "content" =>
        #     "You are one component of a larger AI artwork system. Your job is to describe what you see."
        # },
        %{"role" => "user", "content" => input}
      ],
      temperature: @temperature,
      max_tokens: @max_tokens
    }

    req_new(
      method: :post,
      url: "/chat/completions",
      json: request_body
    )
  end

  defp req_new(opts) do
    token = System.get_env("OPENAI_API_TOKEN")

    Keyword.merge(
      [
        base_url: "https://api.openai.com/v1",
        receive_timeout: 10_000,
        auth: {:bearer, token}
      ],
      opts
    )
    |> Req.new()
  end
end
