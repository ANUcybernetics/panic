defmodule Panic.Models.Platforms.Replicate do
  @api_token System.get_env("REPLICATE_API_TOKEN")
  @url "https://api.replicate.com/v1"
  @headers %{
    "Authorization" => "Token #{@api_token}",
    "Content-Type" => "application/json"
  }

  def get_model_versions(model) do
    url = "#{@url}/models/#{model}/versions"
    case HTTPoison.get(url, @headers, hackney: [pool: :default]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, %{"results" => results}} = Jason.decode(response_body)
        results
    end
  end

  def get_latest_model_version(model) do
    get_model_versions(model) |> List.last |> Map.get("id")
  end

  def get_status(prediction_id) do
    url = "#{@url}/predictions/#{prediction_id}"
    case HTTPoison.get(url, @headers, hackney: [pool: :default]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, body} = Jason.decode(response_body)
        body
    end
  end

  def get(prediction_id) do
    url = "#{@url}/predictions/#{prediction_id}"

    case HTTPoison.get(url, @headers, hackney: [pool: :default]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, body} = Jason.decode(response_body)
        case body do
          %{"status" => "succeeded"} ->
            body
          %{"status" => status} when status in ~w(starting processing) ->
            get(prediction_id)
        end
    end
  end

  def create("kuprel/min-dalle" = model, prompt) do
    %{"output" => output_url} = create(model, %{prompt: prompt, grid_size: 1})
    output_url
  end

  def create("rmokady/clip_prefix_caption" = model, image_url) do
    %{"output" => [%{"text" => text} | _]} = create(model, %{image: image_url})
    text
  end

  def create(model, input_params) do
    url = "#{@url}/predictions"
    model_version = get_latest_model_version(model)

    {:ok, request_body} = Jason.encode(%{version: model_version, input: input_params})

    case HTTPoison.post(url, request_body, @headers, hackney: [pool: :default]) do
      {:ok, %HTTPoison.Response{status_code: 201, body: response_body}} ->
        {:ok, body} = Jason.decode(response_body)
        get(body["id"])
    end
  end

  # def run_long_job(prompt) do
  #   PetalPro.BackgroundTask.run(fn prompt ->
  #     {:ok, image_url} = Replicate.create "two white dudes having a video call"
  #     ## use the jobs table (Oban) with a whole new table
  #     ## experiment row with ID, then pubsub -> job done, update assigns
  #   end)
  # end
end
