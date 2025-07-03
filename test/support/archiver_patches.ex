defmodule Panic.Test.ArchiverPatches do
  @moduledoc """
  Test patches for the Archiver module to avoid real file downloads and S3 uploads.

  These patches are automatically applied in test_helper.exs.
  """

  alias Panic.Engine.Archiver

  def apply_patches do
    Repatch.patch(Archiver, :download_file, fn _url ->
      {:ok, "/tmp/dummy_file.webp"}
    end)

    Repatch.patch(Archiver, :convert_file, fn filename, _dest_rootname ->
      {:ok, filename}
    end)

    Repatch.patch(Archiver, :upload_to_s3, fn _file_path ->
      {:ok, "https://dummy-s3-url.com/test-file.webp"}
    end)
  end
end
