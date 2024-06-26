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

  @doc "helper function for preparing canned responses for testing"
  def append_resp_to_canned_data(resp) do
    filename =
      "test/support/canned_responses/openai.json"

    filename
    |> File.read!()
    |> Jason.decode!()
    |> Map.put(resp.body["model"], %{
      "input" => "TODO",
      "output_fragment" => "TODO",
      "response" => Map.from_struct(resp)
    })
    |> Jason.encode!(pretty: true)
    |> then(fn data -> File.write!(filename, data) end)
  end
end
