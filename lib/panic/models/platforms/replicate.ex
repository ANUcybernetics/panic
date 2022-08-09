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
end
