defmodule Panic.Models.Platforms.Replicate do
  @url "https://api.replicate.com/v1"
  @nsfw_placeholder "https://res.cloudinary.com/teepublic/image/private/s--XZyAQb6t--/t_Preview/b_rgb:191919,c_lpad,f_jpg,h_630,q_90,w_1200/v1532173190/production/designs/2918923_0.jpg"
  @recv_timeout 30_000

  def get_model_versions(model) do
    url = "#{@url}/models/#{model}/versions"

    case HTTPoison.get(url, headers(), hackney: [pool: :default]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, %{"results" => results}} = Jason.decode(response_body)
        results
    end
  end

  def get_latest_model_version(model) do
    get_model_versions(model) |> List.first() |> Map.get("id")
  end

  def get_status(prediction_id) do
    url = "#{@url}/predictions/#{prediction_id}"

    case HTTPoison.get(url, headers(), hackney: [pool: :default], recv_timeout: @recv_timeout) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, body} = Jason.decode(response_body)
        body
    end
  end

  def get(prediction_id) do
    url = "#{@url}/predictions/#{prediction_id}"

    case HTTPoison.get(url, headers(), hackney: [pool: :default], recv_timeout: @recv_timeout) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, body} = Jason.decode(response_body)

        case body do
          %{"status" => "succeeded"} ->
            {:ok, body}

          %{"status" => "failed", "error" => "NSFW" <> _} ->
            {:error, :nsfw}

          %{"status" => "failed", "error" => error} ->
            {:error, error}

          %{"status" => status} when status in ~w(starting processing) ->
            ## recursion case; doesn't need a tuple
            get(prediction_id)
        end
    end
  end

  def cancel(prediction_id) do
    url = "#{@url}/predictions/#{prediction_id}/cancel"
    HTTPoison.post(url, [], headers(), hackney: [pool: :default])
  end

  ## text to image
  def create("stability-ai/stable-diffusion" = model, prompt) do
    input_params = %{
      prompt: prompt,
      num_inference_steps: 50,
      guidance_scale: 7.5,
      width: 1024,
      height: 576
    }

    %{"output" => [image_url]} = create_and_wait(model, input_params)
    image_url
  end

  ## text to image
  def create("prompthero/openjourney" = model, prompt) do
    input_params = %{
      prompt: prompt,
      num_inference_steps: 50,
      guidance_scale: 7.5,
      width: 1024,
      height: 576
    }

    %{"output" => [image_url]} = create_and_wait(model, input_params)
    image_url
  end

  ## text to image
  def create("cjwbw/stable-diffusion-high-resolution" = model, prompt) do
    input_params = %{
      prompt: prompt,
      steps: 50,
      scale: 7.5,
      ori_width: 256,
      ori_height: 256
    }

    %{"output" => image_url} = create_and_wait(model, input_params)
    image_url
  end

  def create("kuprel/min-dalle" = model, prompt) do
    %{"output" => [image_url]} =
      create_and_wait(model, %{text: prompt, grid_size: 1, progressive_outputs: 0})

    image_url
  end

  def create("benswift/min-dalle" = model, prompt) do
    %{"output" => [image_url]} =
      create_and_wait(model, %{text: prompt, grid_size: 1, progressive_outputs: 0})

    image_url
  end

  def create("afiaka87/retrieval-augmented-diffusion" = model, prompt) do
    create_and_wait(model, %{prompt: prompt, width: 256, height: 256})
  end

  def create("laion-ai/ongo" = model, prompt) do
    %{"output" => image_urls} =
      create_and_wait(
        model,
        %{text: prompt, batch_size: 1, height: 256, width: 256, intermediate_outputs: 0}
      )

    List.last(image_urls)
  end

  ## image to text
  def create("methexis-inc/img2prompt" = model, image_url) do
    %{"output" => text} = create_and_wait(model, %{image: image_url})
    text
  end

  def create("charlesfrye/text-recognizer-gpu" = model, image_url) do
    %{"output" => text} = create_and_wait(model, %{image: image_url})
    text
  end

  def create("rmokady/clip_prefix_caption" = model, image_url) do
    %{"output" => text} = create_and_wait(model, %{image: image_url})
    text
  end

  def create("j-min/clip-caption-reward" = model, image_url) do
    %{"output" => text} = create_and_wait(model, %{image: image_url})
    text
  end

  ## text to text
  def create("kyrick/prompt-parrot" = model, prompt) do
    %{"output" => text} = create_and_wait(model, %{prompt: prompt})

    ## for some reason this model returns multiple prompts, but separated by a
    ## "separator" string rather than in a list, so we split it here and choose
    ## one at random
    text
    |> String.split("\n------------------------------------------\n")
    |> Enum.random()
  end

  def create("2feet6inches/cog-prompt-parrot" = model, prompt) do
    %{"output" => text} = create_and_wait(model, %{prompt: prompt})

    text
    |> String.split("\n")
    |> Enum.random()
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

    {:ok, %HTTPoison.Response{status_code: 201, body: response_body}} =
      HTTPoison.post(url, request_body, headers(), hackney: [pool: :default])

    {:ok, %{"id" => id}} = Jason.decode(response_body)

    case get(id) do
      {:ok, body} -> body
      {:error, :nsfw} -> %{"output" => [@nsfw_placeholder]}
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
