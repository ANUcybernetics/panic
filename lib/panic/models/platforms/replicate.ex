defmodule Panic.Models.Platforms.Replicate do
  @api_token System.get_env("REPLICATE_API_TOKEN")
  @url "https://api.replicate.com/v1/"
  @headers %{
    "Authorization" => "Token #{@api_token}",
    "Content-Type" => "application/json"
  }

  def get_model_versions(model) do
    url = "#{@url}/models/#{model}/versions"
    case HTTPoison.get(url, @headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, %{"results" => results}} = Jason.decode(body)
        IO.puts results
      {:ok, %HTTPoison.Response{status_code: 404}} ->
        IO.puts "Not found :("
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.inspect reason
    end
  end
end
