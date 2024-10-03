defmodule Panic.Workers.Tigrisizer do
  @moduledoc """
  An Oban worker module responsible for uploading files to Tigris storage.

  This is necessary because replicate's file hosting (on `replicate.delivery`)
  expires after ~1h, which is fine for "live watchalong" running of panic, but
  not useful if you want to go back and look at the outputs later.
  """

  use Oban.Worker, queue: :default

  @bucket "panic-invocation-outputs"

  defp s3_req_new(opts) do
    Req.new()
    |> ReqS3.attach()
    |> Req.merge(opts)
  end

  defp download_file(url) do
    [url: url]
    |> Req.get()
    |> case do
      {:ok, %Req.Response{body: body, status: status}} when status in 200..299 -> {:ok, body}
      {:error, reason} -> {:error, reason}
    end
  end

  defp upload_to_s3(key, body) do
    [url: "s3://#{@bucket}/#{key}"]
    |> s3_req_new()
    |> Req.put(body: body)
    |> case do
      {:ok, %Req.Response{status: status}} when status in 200..299 -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Performs the tigris upload job.

  This callback is the implementation of the Oban.Worker behavior. It processes
  the job with the given arguments, downloads the file to a temporary location,
  and prepares it for further processing.

  ## Returns
    - {:ok, key} if the file is successfully uploaded to Tigris
    - {:error, reason} if there's an error during the download or upload process
  """
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "invocation_id" => invocation_id}}) do
    with {:ok, user} <- Ash.get(Panic.Accounts.User, user_id, authorize?: false),
         {:ok, invocation} <- Ash.get(Panic.Engine.Invocation, invocation_id, actor: user) do
      case invocation.state do
        :completed ->
          upload_output_to_tigris(invocation)

        _ ->
          {:ok, :skipped}
      end
    end
  end

  defp upload_output_to_tigris(invocation) do
    extension = Path.extname(invocation.output)
    temp_path = Path.join(System.tmp_dir!(), "#{invocation.id}-output#{extension}")

    try do
      with {:ok, file_content} <- download_file(invocation.output),
           :ok <- File.write(temp_path, file_content),
           :ok <- upload_to_s3("#{invocation.id}-output.jpg", file_content),
           {:ok, _invocation} <- Panic.Engine.update_output(invocation, temp_path) do
        {:ok, :uploaded}
      else
        {:error, reason} ->
          {:error, "Failed to process invocation: #{inspect(reason)}"}
      end
    after
      File.rm(temp_path)
    end
  end
end
