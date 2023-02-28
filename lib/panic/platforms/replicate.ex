defmodule Panic.Platforms.Replicate do
  @url "https://api.replicate.com/v1"
  # @recv_timeout 10_000

  @doc """
  Map of model info

  Keys are binaries of the form `platform:user/model-name`, and values are maps
  the following keys:

  - `name`: human readable name for the model
  - `description`: brief description of the model (supports markdown)
  - `input`: input type (either `:text`, `:image` or `:audio`)
  - `output`: output type (either `:text`, `:image` or `:audio`)

  This information is stored in code (rather than in the database) because each
  model requires bespoke code to pull out the relevant return value (see the
  various versions of `create/3` in this module) and trying to keep that code in
  sync with this info in the database would be a nightmare.
  """
  def all_model_info do
    %{
      "replicate:kuprel/min-dalle" => %{
        path: "kuprel/min-dalle",
        name: "DALL·E Mini",
        description: "",
        input: :text,
        output: :image
      },
      "replicate:kyrick/prompt-parrot" => %{
        path: "kyrick/prompt-parrot",
        name: "Prompt Parrot",
        description: "",
        input: :text,
        output: :text
      },
      "replicate:2feet6inches/cog-prompt-parrot" => %{
        path: "2feet6inches/cog-prompt-parrot",
        name: "Cog Prompt Parrot",
        description: "",
        input: :text,
        output: :text
      },
      "replicate:rmokady/clip_prefix_caption" => %{
        path: "rmokady/clip_prefix_caption",
        name: "Clip Prefix Caption",
        description: "",
        input: :image,
        output: :text
      },
      "replicate:j-min/clip-caption-reward" => %{
        path: "j-min/clip-caption-reward",
        name: "Clip Caption Reward",
        description: "",
        input: :image,
        output: :text
      },
      "replicate:salesforce/blip-2" => %{
        path: "salesforce/blip-2",
        name: "BLIP2",
        description: "",
        input: :image,
        output: :text
      },
      "replicate:stability-ai/stable-diffusion" => %{
        path: "stability-ai/stable-diffusion",
        name: "Stable Diffusion",
        description: "",
        input: :text,
        output: :image
      },
      "replicate:cloneofsimo/lora-socy" => %{
        path: "cloneofsimo/lora",
        name: "SOCY SD",
        description: "",
        input: :text,
        output: :image
      },
      "replicate:timothybrooks/instruct-pix2pix" => %{
        path: "timothybrooks/instruct-pix2pix",
        name: "Instruct pix2pix",
        description: "",
        input: :image,
        output: :image
      }
    }
  end

  def get_model_versions(model, tokens) do
    url = "#{@url}/models/#{model |> Panic.Platforms.model_info() |> Map.get(:path)}/versions"

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

  def get_latest_model_version(model, tokens) do
    get_model_versions(model, tokens) |> List.first() |> Map.get("id")
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

  def create_and_wait(model, input_params, tokens) do
    request_body = %{
      version: get_latest_model_version(model, tokens),
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
  def create("replicate:stability-ai/stable-diffusion" = model, prompt, tokens) do
    input_params = %{
      prompt: prompt,
      num_inference_steps: 50,
      guidance_scale: 7.5,
      width: 1024,
      height: 576
    }

    with {:ok, %{"output" => [image_url]}} <- create_and_wait(model, input_params, tokens) do
      {:ok, image_url}
    end
  end

  def create("replicate:cloneofsimo/lora-socy" = model, prompt, tokens) do
    input_params = %{
      prompt: "#{prompt} in the style of <1>",
      width: 1024,
      height: 576,
      lora_urls:
        "https://replicate.delivery/pbxt/eIfm9M0WYEnnjUKQxyumkqiPtr6Pi0D8ee1bGufE74ieUpXIE/tmp5xnilpplHEADER20IMAGESzip.safetensors"
    }

    with {:ok, %{"output" => [image_url]}} <- create_and_wait(model, input_params, tokens) do
      {:ok, image_url}
    end
  end

  def create("replicate:kuprel/min-dalle" = model, prompt, tokens) do
    with {:ok, %{"output" => [image_url]}} <-
           create_and_wait(model, %{text: prompt, grid_size: 1, progressive_outputs: 0}, tokens) do
      {:ok, image_url}
    end
  end

  def create("replicate:rmokady/clip_prefix_caption" = model, image_url, tokens) do
    with {:ok, %{"output" => text}} <- create_and_wait(model, %{image: image_url}, tokens) do
      {:ok, text}
    end
  end

  def create("replicate:j-min/clip-caption-reward" = model, image_url, tokens) do
    with {:ok, %{"output" => text}} <- create_and_wait(model, %{image: image_url}, tokens) do
      {:ok, text}
    end
  end

  def create("replicate:salesforce/blip-2" = model, image_url, tokens) do
    with {:ok, %{"output" => text}} <-
           create_and_wait(model, %{image: image_url, caption: true}, tokens) do
      {:ok, text}
    end
  end

  def create("replicate:timothybrooks/instruct-pix2pix" = model, input_image_url, tokens) do
    with {:ok, %{"output" => [output_image_url]}} <-
           create_and_wait(
             model,
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
  def create("replicate:kyrick/prompt-parrot" = model, prompt, tokens) do
    with {:ok, %{"output" => text}} <- create_and_wait(model, %{prompt: prompt}, tokens) do
      ## for some reason this model returns multiple prompts, but separated by a
      ## "separator" string rather than in a list, so we split it here and choose
      ## one at random
      {:ok,
       text |> String.split("\n------------------------------------------\n") |> Enum.random()}
    end
  end

  def create("replicate:2feet6inches/cog-prompt-parrot" = model, prompt, tokens) do
    with {:ok, %{"output" => text}} <- create_and_wait(model, %{prompt: prompt}, tokens) do
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
