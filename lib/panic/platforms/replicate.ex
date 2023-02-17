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
        name: "DALL·E Mini",
        description: "",
        input: :text,
        output: :image
      },
      "replicate:kyrick/prompt-parrot" => %{
        name: "Prompt Parrot",
        description: "",
        input: :text,
        output: :text
      },
      "replicate:2feet6inches/cog-prompt-parrot" => %{
        name: "Cog Prompt Parrot",
        description: "",
        input: :text,
        output: :text
      },
      "replicate:rmokady/clip_prefix_caption" => %{
        name: "Clip Prefix Caption",
        description: "",
        input: :image,
        output: :text
      },
      "replicate:j-min/clip-caption-reward" => %{
        name: "Clip Caption Reward",
        description: "",
        input: :image,
        output: :text
      },
      "salesforce/blip-2" => %{
        name: "BLIP2",
        description: "",
        input: :image,
        output: :text
      },
      "replicate:stability-ai/stable-diffusion" => %{
        name: "Stable Diffusion",
        description: "",
        input: :text,
        output: :image
      },
      "22-hours/vintedois-diffusion" => %{
        name: "Vintedois Stable Diffusion",
        description: "",
        input: :text,
        output: :image
      },
      "timothybrooks/instruct-pix2pix" => %{
        name: "Instruct pix2pix",
        description: "",
        input: :image,
        output: :image
      }
    }
  end

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

    case create_and_wait(model, input_params, user) do
      {:ok, %{"output" => [image_url]}} -> {:ok, image_url}
      {:error, reason} -> {:error, reason}
    end
  end

  def create("22-hours/vintedois-diffusion" = model, prompt, user) do
    input_params = %{
      prompt: prompt,
      num_inference_steps: 25,
      width: 640,
      height: 448
    }

    case create_and_wait(model, input_params, user) do
      {:ok, %{"output" => [image_url]}} -> {:ok, image_url}
      {:error, reason} -> {:error, reason}
    end
  end

  def create("kuprel/min-dalle" = model, prompt, user) do
    {:ok, %{"output" => [image_url]}} =
      create_and_wait(model, %{text: prompt, grid_size: 1, progressive_outputs: 0}, user)

    {:ok, image_url}
  end

  def create("rmokady/clip_prefix_caption" = model, image_url, user) do
    {:ok, %{"output" => text}} = create_and_wait(model, %{image: image_url}, user)
    {:ok, text}
  end

  def create("j-min/clip-caption-reward" = model, image_url, user) do
    {:ok, %{"output" => text}} = create_and_wait(model, %{image: image_url}, user)
    {:ok, text}
  end

  def create("salesforce/blip-2" = model, image_url, user) do
    {:ok, %{"output" => text}} = create_and_wait(model, %{image: image_url, caption: true}, user)
    {:ok, text}
  end

  def create("timothybrooks/instruct-pix2pix" = model, input_image_url, user) do
    {:ok, %{"output" => [output_image_url]}} =
      create_and_wait(
        model,
        %{
          image: input_image_url,
          prompt: "change the environment, keep the human and technology"
        },
        user
      )

    {:ok, output_image_url}
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
