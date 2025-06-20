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
  Archives an invocation's output and updates the next invocation's metadata.

  This function downloads the output from the given invocation, converts it if needed,
  uploads it to S3, and updates the next invocation's metadata with the S3 URL.

  ## Parameters
  - `invocation` - The invocation whose output should be archived
  - `next_invocation` - The next invocation to update with the archived URL

  ## Returns
  - `:ok` on success
  - `{:error, reason}` on failure
  """
  def archive_invocation(invocation, next_invocation) do
    # Download the file from the output URL
    case download_file(invocation.output) do
      {:ok, filename} ->
        # Convert to appropriate format
        dest_rootname = "invocation_#{invocation.id}_#{next_invocation.id}"

        case convert_file(filename, dest_rootname) do
          {:ok, converted_filename} ->
            # Upload to S3
            case upload_to_s3(converted_filename) do
              {:ok, s3_url} ->
                # Update the next invocation's metadata with the S3 URL
                metadata = Map.put(next_invocation.metadata, "previous_output_url", s3_url)

                try do
                  next_invocation
                  |> Ash.Changeset.for_update(:update, %{metadata: metadata})
                  |> Ash.update!(authorize?: false)

                  # Clean up temporary files
                  File.rm(filename)
                  if converted_filename != filename, do: File.rm(converted_filename)

                  :ok
                rescue
                  e ->
                    Logger.error("Failed to update invocation metadata: #{inspect(e)}")
                    {:error, :metadata_update_failed}
                end

              {:error, reason} ->
                Logger.error("Failed to upload to S3: #{inspect(reason)}")
                File.rm(filename)
                {:error, :upload_failed}
            end

          {:error, reason} ->
            Logger.error("Failed to convert file: #{inspect(reason)}")
            File.rm(filename)
            {:error, :conversion_failed}
        end

      {:error, reason} ->
        Logger.error("Failed to download file: #{inspect(reason)}")
        {:error, :download_failed}
    end
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
    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        filename = Path.join(System.tmp_dir(), "download_#{System.unique_integer()}")
        File.write!(filename, body)
        {:ok, filename}

      {:error, reason} ->
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

    case Req.put(req, url: "https://fly.storage.tigris.dev/#{bucket}/#{key}", body: File.read!(file_path)) do
      {:ok, %{status: status}} when status in 200..299 ->
        {:ok, "https://fly.storage.tigris.dev/#{bucket}/#{key}"}

      {:ok, %{status: status, body: body}} ->
        {:error, "Upload failed with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
