defmodule Panic.Platforms.Replicate do
  @moduledoc false
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

  def get_status(prediction_id, token) do
    [url: "predictions/#{prediction_id}", auth: {:bearer, token}]
    |> req_new()
    |> Req.request()
    |> case do
      {:ok, %Req.Response{body: body, status: 200}} ->
        body

      {:ok, %Req.Response{body: %{"detail" => message}, status: status}} when status >= 400 ->
        {:error, message}
    end
  end

  def get(prediction_id, token) do
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

          %{"status" => status} when status in ~w(starting processing) ->
            ## recursion case; doesn't need a tuple
            get(prediction_id, token)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def cancel(prediction_id, token) do
    [method: :post, url: "predictions/#{prediction_id}/cancel", auth: {:bearer, token}]
    |> req_new()
    |> Req.request()
  end

  def invoke(model, input, token) do
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
          get(id, token)

        {:ok, %Req.Response{body: %{"detail" => message}, status: 410}} ->
          {:error, message}

        {:ok, %Req.Response{body: %{"detail" => message}, status: status}} when status >= 400 ->
          {:error, message}

        {:error, reason} ->
          {:error, reason}
      end
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
