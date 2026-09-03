defmodule Panic.Engine.Archiver do
  @moduledoc """
  Handles archiving of invocation outputs to S3 storage.

  This module is responsible for:
  - Downloading invocation outputs from URLs
  - Converting files to appropriate formats
  - Uploading processed files to S3
  - Updating invocation metadata with archived URLs

  ## External Dependencies

  File conversion requires external tools to be installed:
  - **ImageMagick** (`convert` command) for image conversion (JPG/PNG → WebP)
  - **FFmpeg** for audio conversion (WAV/OGG/FLAC → MP3)

  If these tools are not available, conversion will fail with an error.
  """

  require Logger

  @doc """
  Archives an invocation's output and updates both invocations.

  This function downloads the output from the given invocation, converts it if needed,
  uploads it to S3, and updates both invocations with the S3 URL:
  - Updates `invocation.output` with the S3 URL
  - Updates `next_invocation.input` with the same S3 URL

  ## Parameters
  - `invocation` - The invocation whose output should be archived
  - `next_invocation` - The next invocation whose input should point to the archived output

  ## Returns
  - `:ok` on success
  - `{:error, reason}` on failure
  """
  def archive_invocation(invocation, next_invocation) do
    case download_file(invocation.output) do
      {:ok, filename} ->
        try do
          convert_and_upload(filename, invocation, next_invocation)
        after
          File.rm(filename)
        end

      {:error, reason} ->
        Logger.error("Failed to download file: #{inspect(reason)}")
        {:error, :download_failed}
    end
  end

  defp convert_and_upload(filename, invocation, next_invocation) do
    case convert_file(filename, "invocation-#{invocation.id}-output") do
      {:ok, converted_filename} ->
        try do
          upload_and_record(converted_filename, invocation, next_invocation)
        after
          if converted_filename != filename, do: File.rm(converted_filename)
        end

      {:error, reason} ->
        Logger.error("Failed to convert file #{filename}: #{inspect(reason)}")
        {:error, :conversion_failed}
    end
  end

  defp upload_and_record(filename, invocation, next_invocation) do
    case upload_to_s3(filename) do
      {:ok, s3_url} ->
        record_archived_url(invocation, next_invocation, s3_url)

      {:error, reason} ->
        Logger.error("Failed to upload to S3: #{inspect(reason)}")
        {:error, :upload_failed}
    end
  end

  # both invocations point at the same file: current.output and next.input
  defp record_archived_url(invocation, next_invocation, s3_url) do
    invocation
    |> Ash.Changeset.for_update(:update_output, %{output: s3_url})
    |> Ash.update!(authorize?: false)

    next_invocation
    |> Ash.Changeset.for_update(:update_input, %{input: s3_url})
    |> Ash.update!(authorize?: false)

    :ok
  rescue
    e ->
      Logger.error("Failed to update invocation records: #{inspect(e)}")
      {:error, :update_failed}
  end

  @doc """
  Downloads a file from the given URL and saves it to a temporary location.

  ## Parameters
  - `url` - The URL to download from

  ## Returns
  - `{:ok, filename}` - Path to the downloaded file
  - `{:error, reason}` - Download error
  """
  def download_file(url) do
    extension = Path.extname(url)
    filename = Path.join(System.tmp_dir(), "download_#{System.unique_integer()}#{extension}")

    # stream straight to disk rather than buffering the whole body on the heap
    case Req.get(url, into: File.stream!(filename)) do
      {:ok, %{status: status}} when status in 200..299 ->
        {:ok, filename}

      {:ok, %{status: status}} ->
        File.rm(filename)
        {:error, {:unexpected_status, status}}

      {:error, reason} ->
        File.rm(filename)
        {:error, reason}
    end
  end

  @doc """
  Converts a file to an appropriate format for archiving.

  Supports conversion of various image and audio formats:
  - WebP/WebM files: No conversion needed
  - JPG/JPEG/PNG images: Convert to WebP using ImageMagick
  - MP3/WAV/OGG/FLAC audio: Convert to MP3 using FFmpeg

  ## Parameters
  - `filename` - Path to the file to convert
  - `dest_rootname` - Base name for the output file

  ## Returns
  - `{:ok, converted_filename}` - Path to the converted file
  - `{:error, reason}` - Conversion error
  """
  def convert_file(filename, dest_rootname) do
    extension = Path.extname(filename)

    case String.downcase(extension) do
      ext when ext in [".webp", ".webm"] ->
        # No conversion needed for webp/webm
        {:ok, filename}

      ext when ext in [".jpg", ".jpeg", ".png"] ->
        output_filename = "#{Path.dirname(filename)}/#{dest_rootname}.webp"

        case System.cmd(
               "convert",
               [
                 filename,
                 "-quality",
                 "75",
                 "-define",
                 "webp:lossless=false",
                 "-define",
                 "webp:method=4",
                 output_filename
               ],
               stderr_to_stdout: true
             ) do
          {_, 0} -> {:ok, output_filename}
          {error, _} -> {:error, "Image conversion failed: #{error}"}
        end

      ext when ext in [".mp3", ".wav", ".ogg", ".flac"] ->
        output_filename = "#{Path.dirname(filename)}/#{dest_rootname}.mp3"

        case System.cmd(
               "ffmpeg",
               [
                 "-i",
                 filename,
                 "-c:a",
                 "libmp3lame",
                 "-b:a",
                 "64k",
                 "-loglevel",
                 "error",
                 output_filename
               ],
               stderr_to_stdout: true
             ) do
          {_, 0} -> {:ok, output_filename}
          {error, _} -> {:error, "Audio conversion failed: #{error}"}
        end

      _ ->
        {:error, "Unsupported file format: #{extension}"}
    end
  end

  @doc """
  Uploads a file to S3 storage.

  ## Parameters
  - `file_path` - Path to the file to upload

  ## Returns
  - `{:ok, s3_url}` - URL of the uploaded file
  - `{:error, reason}` - Upload error
  """
  def upload_to_s3(file_path) do
    bucket = "panic-invocation-outputs"
    key = Path.basename(file_path)

    req = ReqS3.attach(Req.new())

    # use s3:// URL format for ReqS3 plugin, not direct HTTPS URL
    case Req.put(req, url: "s3://#{bucket}/#{key}", body: File.read!(file_path)) do
      {:ok, %{status: status}} when status in 200..299 ->
        {:ok, "https://fly.storage.tigris.dev/#{bucket}/#{key}"}

      {:ok, %{status: status, body: body}} ->
        {:error, "Upload failed with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
