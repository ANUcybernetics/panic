defmodule Panic.Models.Platforms.Replicate do
  @url "https://api.replicate.com/v1"

  def get_model_versions(model) do
    url = "#{@url}/models/#{model}/versions"

    case HTTPoison.get(url, headers(), hackney: [pool: :default]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, %{"results" => results}} = Jason.decode(response_body)
        results
    end
  end

  def get_latest_model_version(model) do
    get_model_versions(model) |> List.last() |> Map.get("id")
  end

  def get_status(prediction_id) do
    url = "#{@url}/predictions/#{prediction_id}"

    case HTTPoison.get(url, headers(), hackney: [pool: :default]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, body} = Jason.decode(response_body)
        body
    end
  end

  def get(prediction_id) do
    url = "#{@url}/predictions/#{prediction_id}"

    case HTTPoison.get(url, headers(), hackney: [pool: :default]) do
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

  ## text to image
  def create("benswift/min-dalle" = model, prompt) do
    %{"output" => image_url} = create_and_wait(model, %{text: prompt, grid_size: 1})
    image_url
  end

  def create("laion-ai/ongo" = model, prompt) do
    %{"output" => image_urls} = create_and_wait(model,
      %{text: prompt,
        batch_size: 1,
        height: 256,
        width: 256,
        intermediate_outputs: 0
      })
    List.last(image_urls)
  end

  ## image to text
  def create("rmokady/clip_prefix_caption" = model, image_url) do
    %{"output" => [%{"text" => text} | _]} = create_and_wait(model, %{image: image_url})
    text
  end

  def create("j-min/clip-caption-reward" = model, image_url) do
    %{"output" => text} = create_and_wait(model, %{image: image_url})
    text
  end

  ## image to image
  def create("netease-gameai/spatchgan-selfie2anime" = model, image_url) do
    %{"output" => [%{"file" => image_url} | _]} = create_and_wait(model, %{image: image_url})
    image_url
  end

  ## text to audio
  def create("annahung31/emopia" = model, prompt) do
    emotion_opts = [
      "High valence, high arousal",
      "Low valence, high arousal",
      "High valence, low arousal",
      "Low valence, low arousal"
    ]

    emotion = Enum.max_by(emotion_opts, fn emotion -> String.bag_distance(emotion, prompt) end)
    seed = string_to_seed(prompt)

    %{"output" => [%{"file" => audio_url} | _]} =
      create_and_wait(model, %{emotion: emotion, seed: seed})

    audio_url
  end

  def create("afiaka87/tortoise-tts" = model, prompt) do
    %{"output" => output} = create_and_wait(model, %{text: prompt})
    output
  end

  def create_and_wait(model, input_params) do
    url = "#{@url}/predictions"
    model_version = get_latest_model_version(model)

    {:ok, request_body} = Jason.encode(%{version: model_version, input: input_params})

    case HTTPoison.post(url, request_body, headers(), hackney: [pool: :default]) do
      {:ok, %HTTPoison.Response{status_code: 201, body: response_body}} ->
        {:ok, body} = Jason.decode(response_body)
        get(body["id"])
    end
  end

  defp headers do
    api_token = Application.fetch_env!(:panic, :replicate_api_token)

    %{
      "Authorization" => "Token #{api_token}",
      "Content-Type" => "application/json"
    }
  end

  defp string_to_seed(string) do
    :crypto.hash(:md5, string)
    |> :binary.decode_unsigned()
    |> Integer.mod(65_536)
  end
end
