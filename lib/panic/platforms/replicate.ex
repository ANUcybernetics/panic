defmodule Panic.Platforms.Replicate do
  @base_url "https://api.replicate.com/v1/"
  # @recv_timeout 10_000

  def get_latest_model_version(model, tokens) do
    case Req.get(url: "models/#{model.info(:path)}", base_url: @base_url, headers: headers(tokens)) do
      {:ok, %Req.Response{body: body, status: 200}} ->
        %{"latest_version" => %{"id" => id}} = body
        id

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_status(prediction_id, tokens) do
    case Req.get(
           url: "predictions/#{prediction_id}",
           base_url: @base_url,
           headers: headers(tokens)
         ) do
      {:ok, %Req.Response{body: body, status: 200}} ->
        body
    end
  end

  def get(prediction_id, tokens) do
    case Req.get(
           url: "predictions/#{prediction_id}",
           base_url: @base_url,
           headers: headers(tokens)
         ) do
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
            get(prediction_id, tokens)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def cancel(prediction_id, tokens) do
    Req.post(
      url: "predictions/#{prediction_id}/cancel",
      base_url: @base_url,
      headers: headers(tokens)
    )
  end

  def create_and_wait(model, input_params, tokens) do
    version = model.info() |> Map.get(:version)

    request_body = %{
      version: version || get_latest_model_version(model, tokens),
      input: input_params
    }

    Req.post(
      url: "predictions",
      base_url: @base_url,
      headers: headers(tokens),
      json: request_body
    )
    |> case do
      {:ok, %Req.Response{body: %{"id" => id}, status: 201}} ->
        get(id, tokens)
    end
  end

  defp headers(%{"Replicate" => token}) do
    %{
      "Authorization" => "Token #{token}",
      "Content-Type" => "application/json"
    }
  end
end
