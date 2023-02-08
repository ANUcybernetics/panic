defmodule Panic.Platforms.Replicate do
  @url "https://api.replicate.com/v1"
  @nsfw_placeholder "https://res.cloudinary.com/teepublic/image/private/s--XZyAQb6t--/t_Preview/b_rgb:191919,c_lpad,f_jpg,h_630,q_90,w_1200/v1532173190/production/designs/2918923_0.jpg"
  # @recv_timeout 10_000

  def get_model_versions(model, user) do
    Finch.build(:get, "#{@url}/models/#{model}/versions", headers(user))
    |> Finch.request(Panic.Finch)
    |> case do
      {:ok, %Finch.Response{body: response_body, status: 200}} ->
        %{"results" => results} = Jason.decode!(response_body)
        results

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_latest_model_version(model, user) do
    get_model_versions(model, user) |> List.first() |> Map.get("id")
  end

  def get_status(prediction_id, user) do
    Finch.build(:get, "#{@url}/predictions/#{prediction_id}", headers(user))
    |> Finch.request(Panic.Finch)
    |> case do
      {:ok, %Finch.Response{body: response_body, status: 200}} ->
        Jason.decode!(response_body)
    end
  end

  def get(prediction_id, user) do
    Finch.build(:get, "#{@url}/predictions/#{prediction_id}", headers(user))
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
            get(prediction_id, user)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def cancel(prediction_id, user) do
    Finch.build(:post, "#{@url}/predictions/#{prediction_id}/cancel", headers(user), [])
    |> Finch.request(Panic.Finch)
  end

  def create_and_wait(model, input_params, user) do
    request_body = %{
      version: get_latest_model_version(model, user),
      input: input_params
    }

    Finch.build(:post, "#{@url}/predictions", headers(user), Jason.encode!(request_body))
    |> Finch.request(Panic.Finch)
    |> case do
      {:ok, %Finch.Response{body: response_body, status: 201}} ->
        Jason.decode!(response_body)
        |> Map.get("id")
        |> get(user)
    end
  end

  ## text to image
  def create("stability-ai/stable-diffusion" = model, prompt, user) do
    input_params = %{
      prompt: prompt,
      num_inference_steps: 50,
      guidance_scale: 7.5,
      width: 1024,
      height: 576
    }

    {:ok, %{"output" => [image_url]}} = create_and_wait(model, input_params, user)
    {:ok, image_url}
  end

  ## text to image
  def create("prompthero/openjourney" = model, prompt, user) do
    input_params = %{
      prompt: prompt,
      num_inference_steps: 50,
      guidance_scale: 7.5,
      width: 1024,
      height: 576
    }

    {:ok, %{"output" => [image_url]}} = create_and_wait(model, input_params, user)
    {:ok, image_url}
  end

  ## text to image
  def create("cjwbw/stable-diffusion-high-resolution" = model, prompt, user) do
    input_params = %{
      prompt: prompt,
      steps: 50,
      scale: 7.5,
      ori_width: 256,
      ori_height: 256
    }

    {:ok, %{"output" => image_url}} = create_and_wait(model, input_params, user)
    {:ok, image_url}
  end

  def create("kuprel/min-dalle" = model, prompt, user) do
    {:ok, %{"output" => [image_url]}} =
      create_and_wait(model, %{text: prompt, grid_size: 1, progressive_outputs: 0}, user)

    {:ok, image_url}
  end

  def create("benswift/min-dalle" = model, prompt, user) do
    {:ok, %{"output" => [image_url]}} =
      create_and_wait(model, %{text: prompt, grid_size: 1, progressive_outputs: 0}, user)

    {:ok, image_url}
  end

  def create("afiaka87/retrieval-augmented-diffusion" = model, prompt, user) do
    create_and_wait(model, %{prompt: prompt, width: 256, height: 256}, user)
  end

  def create("laion-ai/ongo" = model, prompt, user) do
    {:ok, %{"output" => image_urls}} =
      create_and_wait(
        model,
        %{text: prompt, batch_size: 1, height: 256, width: 256, intermediate_outputs: 0},
        user
      )

    {:ok, List.last(image_urls)}
  end

  ## image to text
  def create("methexis-inc/img2prompt" = model, image_url, user) do
    {:ok, %{"output" => text}} = create_and_wait(model, %{image: image_url}, user)
    {:ok, text}
  end

  def create("charlesfrye/text-recognizer-gpu" = model, image_url, user) do
    {:ok, %{"output" => text}} = create_and_wait(model, %{image: image_url}, user)
    {:ok, text}
  end

  def create("rmokady/clip_prefix_caption" = model, image_url, user) do
    {:ok, %{"output" => text}} = create_and_wait(model, %{image: image_url}, user)
    {:ok, text}
  end

  def create("j-min/clip-caption-reward" = model, image_url, user) do
    {:ok, %{"output" => text}} = create_and_wait(model, %{image: image_url}, user)
    {:ok, text}
  end

  ## text to text
  def create("kyrick/prompt-parrot" = model, prompt, user) do
    {:ok, %{"output" => text}} = create_and_wait(model, %{prompt: prompt}, user)
    ## for some reason this model returns multiple prompts, but separated by a
    ## "separator" string rather than in a list, so we split it here and choose
    ## one at random
    {:ok, text |> String.split("\n------------------------------------------\n") |> Enum.random()}
  end

  def create("2feet6inches/cog-prompt-parrot" = model, prompt, user) do
    {:ok, %{"output" => text}} = create_and_wait(model, %{prompt: prompt}, user)
    {:ok, text |> String.split("\n") |> Enum.random()}
  end

  ## image to image
  def create("netease-gameai/spatchgan-selfie2anime" = model, image_url, user) do
    {:ok, %{"output" => [%{"file" => image_url} | _]}} =
      create_and_wait(model, %{image: image_url}, user)

    {:ok, image_url}
  end

  ## text to audio
  def create("annahung31/emopia" = model, prompt, user) do
    emotion_opts = [
      "High valence, high arousal",
      "Low valence, high arousal",
      "High valence, low arousal",
      "Low valence, low arousal"
    ]

    emotion = Enum.max_by(emotion_opts, fn emotion -> String.bag_distance(emotion, prompt) end)
    seed = string_to_seed(prompt)

    {:ok, %{"output" => [%{"file" => audio_url} | _]}} =
      create_and_wait(model, %{emotion: emotion, seed: seed}, user)

    {:ok, audio_url}
  end

  def create("afiaka87/tortoise-tts" = model, prompt, user) do
    {:ok, %{"output" => output}} = create_and_wait(model, %{text: prompt}, user)
    {:ok, output}
  end

  defp headers(user) do
    %Panic.Accounts.APIToken{token: token} = Panic.Accounts.get_api_token!(user, "Replicate")

    %{
      "Authorization" => "Token #{token}",
      "Content-Type" => "application/json"
    }
  end

  defp string_to_seed(string) do
    :crypto.hash(:md5, string)
    |> :binary.decode_unsigned()
    |> Integer.mod(65_536)
  end
end
