defmodule Panic.Platforms.OpenAI do
  # TODO perhaps make these defaults, but also pull from the Model struct?
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
    request_body = %{
      model: model.fetch!(:id),
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

    req_new(method: :post, url: "/chat/completions", json: request_body)
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

  defp req_new(opts) do
    token = Application.get_env(:panic, :api_tokens, :openai)

    [
      base_url: "https://api.openai.com/v1",
      receive_timeout: 10_000,
      auth: {:bearer, token}
    ]
    |> Keyword.merge(Application.get_env(:panic, :openai_req_options, []))
    |> Keyword.merge(opts)
    |> Req.new()
    |> Req.Request.prepend_request_steps(add_api_token: &add_api_token/1)
  end

  @doc """
  add the API token to the request headers

  The API token for the current user (actor) must
  exist in the DB.
  """
  def add_api_token(request) do
    put_in(request.options[:auth], {:bearer, "a new value"})
  end
end
