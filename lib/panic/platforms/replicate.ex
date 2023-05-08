defmodule Panic.Platforms.Replicate do
  @url "https://api.replicate.com/v1"
  # @recv_timeout 10_000

  def get_model_versions(model_id, tokens) do
    url = "#{@url}/models/#{model_id |> Panic.Platforms.model_info() |> Map.get(:path)}/versions"

    Finch.build(:get, url, headers(tokens))
    |> Finch.request(Panic.Finch)
    |> case do
      {:ok, %Finch.Response{body: response_body, status: 200}} ->
        %{"results" => results} = Jason.decode!(response_body)
        results

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_latest_model_version(model_id, tokens) do
    get_model_versions(model_id, tokens) |> List.first() |> Map.get("id")
  end

  def get_status(prediction_id, tokens) do
    Finch.build(:get, "#{@url}/predictions/#{prediction_id}", headers(tokens))
    |> Finch.request(Panic.Finch)
    |> case do
      {:ok, %Finch.Response{body: response_body, status: 200}} ->
        Jason.decode!(response_body)
    end
  end

  def get(prediction_id, tokens) do
    Finch.build(:get, "#{@url}/predictions/#{prediction_id}", headers(tokens))
    |> Finch.request(Panic.Finch)
    |> case do
      {:ok, %Finch.Response{body: response_body, status: 200}} ->
        case Jason.decode!(response_body) do
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
    Finch.build(:post, "#{@url}/predictions/#{prediction_id}/cancel", headers(tokens), [])
    |> Finch.request(Panic.Finch)
  end

  def create_and_wait(model_id, input_params, tokens) do
    version =
      model_id
      |> Panic.Platforms.model_info()
      |> Map.get(:version)

    request_body = %{
      version: version || get_latest_model_version(model_id, tokens),
      input: input_params
    }

    Finch.build(:post, "#{@url}/predictions", headers(tokens), Jason.encode!(request_body))
    |> Finch.request(Panic.Finch)
    |> case do
      {:ok, %Finch.Response{body: response_body, status: 201}} ->
        Jason.decode!(response_body)
        |> Map.get("id")
        |> get(tokens)
    end
  end

  ## text to image
  def create("replicate:stability-ai/stable-diffusion" = model_id, prompt, tokens) do
    input_params = %{
      prompt: prompt,
      num_inference_steps: 50,
      guidance_scale: 7.5,
      width: 1024,
      height: 576
    }

    with {:ok, %{"output" => [image_url]}} <- create_and_wait(model_id, input_params, tokens) do
      {:ok, image_url}
    end
  end

  def create("replicate:cloneofsimo/lora-socy" = model_id, prompt, tokens) do
    input_params = %{
      prompt: "#{prompt} in the style of <1>",
      width: 1024,
      height: 576,
      lora_urls:
        "https://replicate.delivery/pbxt/eIfm9M0WYEnnjUKQxyumkqiPtr6Pi0D8ee1bGufE74ieUpXIE/tmp5xnilpplHEADER20IMAGESzip.safetensors"
    }

    with {:ok, %{"output" => [image_url]}} <- create_and_wait(model_id, input_params, tokens) do
      {:ok, image_url}
    end
  end

  def create("replicate:kuprel/min-dalle" = model_id, prompt, tokens) do
    with {:ok, %{"output" => [image_url]}} <-
           create_and_wait(
             model_id,
             %{text: prompt, grid_size: 1, progressive_outputs: 0},
             tokens
           ) do
      {:ok, image_url}
    end
  end

  def create("replicate:rmokady/clip_prefix_caption" = model_id, image_url, tokens) do
    with {:ok, %{"output" => text}} <- create_and_wait(model_id, %{image: image_url}, tokens) do
      {:ok, text}
    end
  end

  def create("replicate:j-min/clip-caption-reward" = model_id, image_url, tokens) do
    with {:ok, %{"output" => text}} <- create_and_wait(model_id, %{image: image_url}, tokens) do
      {:ok, text}
    end
  end

  def create("replicate:salesforce/blip-2" = model_id, image_url, tokens) do
    with {:ok, %{"output" => text}} <-
           create_and_wait(model_id, %{image: image_url, caption: true}, tokens) do
      {:ok, text}
    end
  end

  def create("replicate:replicate/vicuna-13b" = model_id, prompt, tokens) do
    with {:ok, %{"output" => output}} <- create_and_wait(model_id, %{prompt: prompt}, tokens) do
      {:ok, Enum.join(output)}
    end
  end

  def create("replicate:timothybrooks/instruct-pix2pix" = model_id, input_image_url, tokens) do
    with {:ok, %{"output" => [output_image_url]}} <-
           create_and_wait(
             model_id,
             %{
               image: input_image_url,
               prompt: "change the environment, keep the human and technology"
             },
             tokens
           ) do
      {:ok, output_image_url}
    end
  end

  ## text to text
  def create("replicate:kyrick/prompt-parrot" = model_id, prompt, tokens) do
    with {:ok, %{"output" => text}} <- create_and_wait(model_id, %{prompt: prompt}, tokens) do
      ## for some reason this model returns multiple prompts, but separated by a
      ## "separator" string rather than in a list, so we split it here and choose
      ## one at random
      {:ok,
       text |> String.split("\n------------------------------------------\n") |> Enum.random()}
    end
  end

  def create("replicate:2feet6inches/cog-prompt-parrot" = model_id, prompt, tokens) do
    with {:ok, %{"output" => text}} <- create_and_wait(model_id, %{prompt: prompt}, tokens) do
      {:ok, text |> String.split("\n") |> Enum.random()}
    end
  end

  defp headers(%{"Replicate" => token}) do
    %{
      "Authorization" => "Token #{token}",
      "Content-Type" => "application/json"
    }
  end
end
