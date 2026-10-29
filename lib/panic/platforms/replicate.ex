defmodule Panic.Platforms.Replicate do
  @moduledoc false
  require Logger

  def get_latest_model_version(%Panic.Model{path: path}, token) do
    [url: "models/#{path}", auth: {:bearer, token}]
    |> req_new()
    |> Req.request()
    |> case do
      {:ok, %Req.Response{body: body, status: 200}} ->
        %{"latest_version" => %{"id" => id}} = body
        {:ok, id}

      {:ok, %Req.Response{body: %{"detail" => message}, status: status}} when status >= 400 ->
        {:error, message}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Polls a prediction until it finishes, pausing between polls. A prediction
  still processing after `timeout_ms` (time spent starting, such as a cold
  boot, doesn't count) is cancelled and returned as an error, so a hung model
  can't stall a run.
  """
  def get(prediction_id, token, timeout_ms) do
    interval_ms =
      :panic
      |> Application.get_env(:replicate_poll_options, [])
      |> Keyword.get(:interval_ms, 1_000)

    poll(prediction_id, token, interval_ms, timeout_ms, nil)
  end

  defp poll(prediction_id, token, interval_ms, timeout_ms, deadline) do
    [url: "predictions/#{prediction_id}", auth: {:bearer, token}]
    |> req_new()
    |> Req.request()
    |> case do
      {:ok, %Req.Response{body: body, status: 200}} ->
        case body do
          %{"status" => "succeeded"} = body ->
            {:ok, body}

          %{"status" => "failed", "error" => error} ->
            if detect_nsfw(error) do
              {:error, :nsfw}
            else
              {:error, error}
            end

          %{"status" => "canceled"} ->
            {:error, "Prediction was canceled"}

          %{"status" => "starting"} ->
            Process.sleep(interval_ms)
            poll(prediction_id, token, interval_ms, timeout_ms, deadline)

          %{"status" => "processing"} ->
            now = System.monotonic_time(:millisecond)
            deadline = deadline || now + timeout_ms

            if now >= deadline do
              cancel(prediction_id, token)
              {:error, "Prediction timed out after #{div(timeout_ms, 1000)}s"}
            else
              Process.sleep(interval_ms)
              poll(prediction_id, token, interval_ms, timeout_ms, deadline)
            end
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp cancel(prediction_id, token) do
    [url: "predictions/#{prediction_id}/cancel", method: :post, auth: {:bearer, token}]
    |> req_new()
    |> Req.request()
  end

  def invoke(model, input, token) do
    with_retry(fn ->
      version =
        case model do
          %{version: version} -> {:ok, version}
          _ -> get_latest_model_version(model, token)
        end

      with {:ok, version_id} <- version do
        request_body = %{version: version_id, input: input}

        [url: "predictions", method: :post, json: request_body, auth: {:bearer, token}]
        |> req_new()
        |> Req.request()
        |> case do
          {:ok, %Req.Response{body: %{"id" => id}, status: 201}} ->
            get(id, token, timeout_ms(model))

          {:ok, %Req.Response{body: %{"detail" => message}, status: 410}} ->
            {:error, message}

          {:ok, %Req.Response{body: %{"detail" => message}, status: status}} when status >= 400 ->
            {:error, message}

          {:error, reason} ->
            {:error, reason}
        end
      end
    end)
  end

  # Text and image models finish in seconds, so a minute without output looks
  # stuck to viewers; audio models can legitimately take longer.
  defp timeout_ms(%{output_type: :audio}), do: to_timeout(minute: 3)
  defp timeout_ms(_model), do: to_timeout(minute: 1)

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

      # a refusal won't change on retry
      {:error, :nsfw} = refusal ->
        refusal

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
