defmodule Panic.Workers.Archiver do
  @moduledoc """
  An Oban worker module responsible for uploading files to Tigris storage.

  This is necessary because replicate's file hosting (on `replicate.delivery`)
  expires after ~1h, which is fine for "live watchalong" running of panic, but
  not useful if you want to go back and look at the outputs later.
  """

  use Oban.Worker, queue: :default

  alias Panic.Engine.Invocation

  @bucket "panic-invocation-outputs"

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
  def perform(%Oban.Job{args: %{"invocation_id" => invocation_id, "next_invocation_id" => next_invocation_id}}) do
    with {:ok, invocation} <- Ash.get(Invocation, invocation_id, authorize?: false),
         {:ok, next_invocation} <- Ash.get(Invocation, next_invocation_id, authorize?: false) do
      case invocation.state do
        :completed ->
          archive_invocation(invocation, next_invocation)

        _ ->
          {:ok, :skipped}
      end
    end
  end

  defp s3_req_new(opts) do
    Req.new()
    |> ReqS3.attach()
    |> Req.merge(opts)
  end

  # download the file at `url` to a temp file, returning the temp file name
  defp download_file(url) do
    temp_file_path = Path.join(System.tmp_dir!(), Path.basename(url))

    [url: url]
    |> Req.get()
    |> case do
      {:ok, %Req.Response{body: body, status: status}} when status in 200..299 ->
        File.write!(temp_file_path, body)
        {:ok, temp_file_path}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp upload_to_s3_and_rm(temp_file) do
    key = Path.basename(temp_file)
    body = File.read!(temp_file)

    [url: "s3://#{@bucket}/#{key}"]
    |> s3_req_new()
    |> Req.put(body: body)
    |> case do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        File.rm(temp_file)
        {:ok, "https://fly.storage.tigris.dev/#{@bucket}/#{key}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def insert(invocation, next_invocation) do
    %{"invocation_id" => invocation.id, "next_invocation_id" => next_invocation.id}
    |> __MODULE__.new()
    |> Oban.insert()
  end

  defp archive_invocation(invocation, next_invocation) do
    with {:ok, temp_file_path} <- download_file(invocation.output),
         {:ok, converted_file_path} <- convert(temp_file_path, "invocation-#{invocation.id}-output"),
         {:ok, url} <- upload_to_s3_and_rm(converted_file_path),
         {:ok, _} <- Panic.Engine.update_output(invocation, url, authorize?: false),
         {:ok, _} <- Panic.Engine.update_input(next_invocation, url, authorize?: false) do
      {:ok, :uploaded}
    else
      {:error, reason} ->
        {:error, "Failed to process invocation: #{inspect(reason)}"}
    end
  end

  defp convert(filename, dest_rootname) do
    extension = Path.extname(filename)

    case String.downcase(extension) do
      ext when ext in [".webp", ".webm"] ->
        {:ok, filename}

      ext when ext in [".jpg", ".jpeg", ".png"] ->
        output_filename = "#{Path.dirname(filename)}/#{dest_rootname}.webp"

        case System.cmd("convert", [
               filename,
               "-quality",
               "75",
               "-define",
               "webp:lossless=false",
               "-define",
               "webp:method=4",
               output_filename
             ]) do
          {_, 0} -> {:ok, output_filename}
          {error, _} -> {:error, "Image conversion failed: #{error}"}
        end

      ext when ext in [".mp3", ".wav", ".ogg", ".flac"] ->
        output_filename = "#{Path.dirname(filename)}/#{dest_rootname}.mp3"

        case System.cmd("ffmpeg", [
               "-i",
               filename,
               # "-t",
               # "8",
               "-c:a",
               "libmp3lame",
               "-b:a",
               "64k",
               "-loglevel",
               "error",
               output_filename
             ]) do
          {_, 0} -> {:ok, output_filename}
          {error, _} -> {:error, "Audio conversion failed: #{error}"}
        end

      _ ->
        {:error, "Unsupported file format: #{extension}"}
    end
  end
end
