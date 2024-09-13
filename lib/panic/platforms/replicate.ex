defmodule Panic.Platforms.Replicate do
  def get_latest_model_version(%Panic.Model{path: path}, token) do
    req_new(url: "models/#{path}", auth: {:bearer, token})
    |> Req.request()
    |> case do
      {:ok, %Req.Response{body: body, status: 200}} ->
        %{"latest_version" => %{"id" => id}} = body
        {:ok, id}

      {:ok, %Req.Response{body: %{"detail" => message}, status: status}} when status >= 400 ->
        {:error, message}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_status(prediction_id, token) do
    req_new(url: "predictions/#{prediction_id}", auth: {:bearer, token})
    |> Req.request()
    |> case do
      {:ok, %Req.Response{body: body, status: 200}} ->
        body

      {:ok, %Req.Response{body: %{"detail" => message}, status: status}} when status >= 400 ->
        {:error, message}
    end
  end

  def get(prediction_id, token) do
    req_new(url: "predictions/#{prediction_id}", auth: {:bearer, token})
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
            get(prediction_id, token)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def cancel(prediction_id, token) do
    req_new(method: :post, url: "predictions/#{prediction_id}/cancel", auth: {:bearer, token})
    |> Req.request()
  end

  def invoke(model, input, token) do
    version =
      case model do
        %{version: version} -> {:ok, version}
        _ -> get_latest_model_version(model, token)
      end

    with {:ok, version_id} <- version do
      request_body = %{version: version_id, input: input}

      req_new(url: "predictions", method: :post, json: request_body, auth: {:bearer, token})
      |> Req.request()
      |> case do
        {:ok, %Req.Response{body: %{"id" => id}, status: 201}} ->
          get(id, token)
      end
    end
  end

  defp req_new(opts) do
    [
      base_url: "https://api.replicate.com/v1/",
      receive_timeout: 10_000
    ]
    |> Keyword.merge(Application.get_env(:panic, :replicate_req_options, []))
    |> Keyword.merge(opts)
    |> Req.new()
  end
end
