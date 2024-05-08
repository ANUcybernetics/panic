defmodule Panic.Platforms.Replicate do
  def get_latest_model_version(model) do
    req_new(url: "models/#{model.info(:path)}")
    |> Req.request()
    |> case do
      {:ok, %Req.Response{body: body, status: 200}} ->
        %{"latest_version" => %{"id" => id}} = body
        id

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_status(prediction_id) do
    req_new(url: "predictions/#{prediction_id}")
    |> Req.request()
    |> case do
      {:ok, %Req.Response{body: body, status: 200}} ->
        body
    end
  end

  def get(prediction_id) do
    req_new(url: "predictions/#{prediction_id}")
    |> Req.request()
    |> case do
      {:ok, %Req.Response{body: body, status: 200}} ->
        case body do
          %{"status" => "succeeded"} = body ->
            {:ok, body}

          %{"status" => "failed", "error" => "NSFW" <> _} ->
            {:error, :nsfw}

          %{"status" => "failed", "error" => error} ->
            {:error, error}

          %{"status" => status} when status in ~w(starting processing) ->
            ## recursion case; doesn't need a tuple
            get(prediction_id)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def cancel(prediction_id) do
    req_new(method: :post, url: "predictions/#{prediction_id}/cancel")
    |> Req.request()
  end

  def create_and_wait(model, input_params) do
    version = model.info() |> Map.get(:version)

    request_body = %{
      version: version || get_latest_model_version(model),
      input: input_params
    }

    Req.post(
      url: "predictions",
      json: request_body
    )
    |> case do
      {:ok, %Req.Response{body: %{"id" => id}, status: 201}} ->
        get(id)
    end
  end

  defp req_new(opts) do
    # FIXME get it from `user.api_tokens` instead
    token = System.get_env("REPLICATE_API_TOKEN")

    [
      base_url: "https://api.replicate.com/v1/",
      receive_timeout: 10_000,
      headers: [{"authorization", "token #{token}"}]
    ]
    |> Keyword.merge(Application.get_env(:panic, :replicate_req_options, []))
    |> Keyword.merge(opts)
    |> Req.new()
  end
end
