defmodule Panic.Models.Platforms.Replicate do
  @api_token System.get_env("REPLICATE_API_TOKEN")
  @url "https://api.replicate.com/v1"
  @headers %{
    "Authorization" => "Token #{@api_token}",
    "Content-Type" => "application/json"
  }

  def get_model_versions(model) do
    url = "#{@url}/models/#{model}/versions"
    case HTTPoison.get(url, @headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, %{"results" => results}} = Jason.decode(response_body)
        results
    end
  end

  def get_latest_model_version(model) do
    get_model_versions(model) |> List.last |> Map.get("id")
  end

  def get_prediction_status(prediction_id) do
    url = "#{@url}/predictions/#{prediction_id}"
    case HTTPoison.get(url, @headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, body} = Jason.decode(response_body)
        body
    end
  end

  def create_prediction(model, input_params) do
    url = "#{@url}/predictions"
    model_version = get_latest_model_version(model)

    {:ok, request_body} = Jason.encode(%{version: model_version, input: input_params})

    case HTTPoison.post(url, request_body, @headers) do
      {:ok, %HTTPoison.Response{status_code: 201, body: response_body}} ->
        {:ok, body} = Jason.decode(response_body)
        return_prediction(body["id"])
    end
  end

  def return_prediction(prediction_id) do
    url = "#{@url}/predictions/#{prediction_id}"

    case HTTPoison.get(url, @headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, body} = Jason.decode(response_body)
        case body do
          %{"status" => "succeeded"} ->
            body
          %{"status" => status} when status in ~w(starting processing) ->
            return_prediction(prediction_id)
        end
    end
  end
end
