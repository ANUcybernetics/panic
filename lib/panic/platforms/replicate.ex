defmodule Panic.Platforms.Replicate do
  @moduledoc false
  require Logger

  def get_latest_model_version(model, token) do
    with {:ok, %{"latest_version" => %{"id" => id}}} <- fetch_model(model, token) do
      {:ok, id}
    end
  end

  @doc """
  Runs `model` on `input`, returning the prediction's output and its usage
  (see `usage/2`). The request waits up to a minute for the prediction to
  finish (Replicate's sync mode), so most predictions need no polling, and
  Replicate cancels any still running at the `cancel_after/2` deadline, so a
  hung model can't stall a run.
  """
  def invoke(model, input, token) do
    with {:ok, prediction} <- predict(model, input, token) do
      {:ok, prediction["output"], usage(model.path, prediction)}
    end
  end

  @doc """
  The usage of a finished `prediction` of the model at `path`: its `metrics`,
  which carry what Replicate bills (`predict_time`, or for official models
  counts like `image_output_count` and `input_token_count`). Some models name
  their token counts the other way round, so those are normalised.
  """
  def usage(path, prediction) do
    prediction
    |> Map.get("metrics", %{})
    |> Map.new(fn
      {"token_input_count", count} -> {"input_token_count", count}
      {"token_output_count", count} -> {"output_token_count", count}
      metric -> metric
    end)
    |> Map.merge(%{"platform" => "replicate", "path" => path})
  end

  defp predict(model, input, token) do
    with_retry(fn ->
      with {:ok, %{"latest_version" => %{"id" => version}} = info} <- fetch_model(model, token) do
        [
          url: "predictions",
          method: :post,
          json: %{version: version, input: input},
          auth: {:bearer, token},
          headers: [{"prefer", "wait=60"}, {"cancel-after", cancel_after(model, info)}],
          receive_timeout: to_timeout(second: 70)
        ]
        |> req_new()
        |> Req.request()
        |> case do
          {:ok, %Req.Response{body: %{"id" => _} = prediction, status: status}}
          when status in 200..299 ->
            outcome(prediction, token)

          {:ok, %Req.Response{body: %{"detail" => message}, status: status}} when status >= 400 ->
            {:error, message}

          {:error, reason} ->
            {:error, reason}
        end
      end
    end)
  end

  # Counted from creation, cold boot included. Official models are always warm
  # and finish in seconds, so a minute without output looks stuck to viewers
  # (audio takes longer); other models may first need minutes to boot.
  defp cancel_after(%{output_type: :audio}, %{"is_official" => true}), do: "3m"
  defp cancel_after(_model, %{"is_official" => true}), do: "1m"
  defp cancel_after(_model, _info), do: "5m"

  # Polls a prediction that outlasted the sync wait. Replicate enforces the
  # deadline, so a canceled or aborted prediction ends the loop like any
  # other unsuccessful status.
  defp outcome(%{"status" => status, "id" => id}, token) when status in ~w(starting processing) do
    :panic
    |> Application.get_env(:replicate_poll_options, [])
    |> Keyword.get(:interval_ms, 1_000)
    |> Process.sleep()

    with {:ok, prediction} <- get(id, token) do
      outcome(prediction, token)
    end
  end

  defp outcome(%{"status" => "succeeded"} = prediction, _token), do: {:ok, prediction}

  defp outcome(%{"status" => "failed", "error" => error}, _token) when is_binary(error) do
    if detect_nsfw(error), do: {:error, :nsfw}, else: {:error, error}
  end

  defp outcome(%{"status" => status}, _token), do: {:error, "Prediction #{status}"}

  defp get(prediction_id, token) do
    get_json("predictions/#{prediction_id}", token)
  end

  defp fetch_model(%Panic.Model{path: path}, token) do
    get_json("models/#{path}", token)
  end

  defp get_json(url, token) do
    [url: url, auth: {:bearer, token}]
    |> req_new()
    |> Req.request()
    |> case do
      {:ok, %Req.Response{body: body, status: 200}} -> {:ok, body}
      {:ok, %Req.Response{body: %{"detail" => message}}} -> {:error, message}
      {:ok, %Req.Response{status: status}} -> {:error, "Replicate returned #{status}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc false
  def with_retry(fun) do
    opts = Application.get_env(:panic, :replicate_retry_options, [])
    max_retries = Keyword.get(opts, :max_retries, 3)
    base_delay_ms = Keyword.get(opts, :base_delay_ms, 1_000)

    do_retry(fun, 0, max_retries, base_delay_ms)
  end

  defp do_retry(fun, attempt, max_retries, base_delay_ms) do
    case fun.() do
      {:ok, _} = success ->
        success

      # a refusal won't change on retry, and a model that couldn't start
      # before its deadline would only keep the run waiting again
      {:error, reason} = error when reason in [:nsfw, "Prediction aborted"] ->
        error

      {:error, _} = error when attempt >= max_retries ->
        error

      {:error, reason} ->
        delay = base_delay_ms * Integer.pow(2, attempt)

        Logger.warning("Replicate invoke failed (attempt #{attempt + 1}): #{inspect(reason)}, retrying in #{delay}ms")

        Process.sleep(delay)
        do_retry(fun, attempt + 1, max_retries, base_delay_ms)
    end
  end

  @doc """
  Detects if an error message indicates NSFW/sensitive content.

  Different Replicate models report NSFW errors in various formats:
  - Some return "NSFW content detected" or messages starting with "NSFW"
  - Some return "The input or output was flagged as sensitive..." with error codes like (E005)
  - Some return other variations of sensitive content messages

  This function centralizes the detection logic for all these variations.
  """
  def detect_nsfw(error_message) when is_binary(error_message) do
    downcased = String.downcase(error_message)

    # Check for various NSFW/sensitive content patterns
    cond do
      # Original pattern: errors starting with "NSFW"
      String.starts_with?(error_message, "NSFW") ->
        true

      # New pattern from seededit-3.0 model
      String.contains?(downcased, "flagged as sensitive") ->
        true

      # Other common patterns
      String.contains?(downcased, "nsfw") ->
        true

      String.contains?(downcased, "content policy") ->
        true

      String.contains?(downcased, "safety checker") ->
        true

      String.contains?(downcased, "inappropriate content") ->
        true

      String.contains?(downcased, "explicit content") ->
        true

      String.contains?(downcased, "adult content") ->
        true

      # Pattern with error codes like (E005)
      String.contains?(downcased, "sensitive") and String.contains?(error_message, "(E00") ->
        true

      true ->
        false
    end
  end

  def detect_nsfw(_), do: false

  defp req_new(opts) do
    [
      base_url: "https://api.replicate.com/v1/",
      receive_timeout: 10_000
    ]
    |> Keyword.merge(Application.get_env(:panic, :replicate_req_options, []))
    |> Keyword.merge(opts)
    |> Req.new()
  end
end
