defmodule Panic.NetworkRunnerFileOpsTest do
  @moduledoc """
  Focused tests for the file-handling helpers inside
  `Panic.Engine.NetworkRunner`.

  * We use `Repatch.private/1` to invoke the private functions.
  * External effects (`System.cmd/3`, S3 uploads) are stubbed with
    `Repatch.patch/3`.
  * The entire module is tagged with `apikeys: true` so these tests
    run only when explicitly requested:

      mix test --include apikeys
  """

  use Panic.DataCase, async: true
  use Repatch.ExUnit

  alias Panic.Engine.NetworkRunner, as: NR

  @moduletag :capture_log
  @moduletag apikeys: true

  describe "convert_file/2" do
    test "returns the original path unchanged for .webp input" do
      tmp_path =
        System.tmp_dir!()
        |> Path.join("convert_src_#{System.unique_integer()}.webp")
        |> tap(&File.write!(&1, "dummy"))

      assert {:ok, ^tmp_path} =
               Repatch.private(NR.convert_file(tmp_path, "ignored_dest_root"))

      File.rm!(tmp_path)
    end

    test "returns an error for unsupported extensions" do
      bad_path =
        System.tmp_dir!()
        |> Path.join("convert_src_#{System.unique_integer()}.txt")
        |> tap(&File.write!(&1, "dummy"))

      assert {:error, "Unsupported file format: .txt"} =
               Repatch.private(NR.convert_file(bad_path, "ignored_dest_root"))

      File.rm!(bad_path)
    end
  end

  describe "upload_to_s3/1" do
    setup do
      # Stub out the S3 interaction so no real network traffic occurs.
      Repatch.patch(ReqS3, :attach, fn req -> req end)

      Repatch.patch(Req, :put, fn _req, _opts ->
        {:ok, %Req.Response{status: 201}}
      end)

      :ok
    end

    test "uploads the file and returns a public URL" do
      tmp_file =
        System.tmp_dir!()
        |> Path.join("upload_src_#{System.unique_integer()}.bin")
        |> tap(&File.write!(&1, "s3-test"))

      assert {:ok, url} = Repatch.private(NR.upload_to_s3(tmp_file))

      assert url =~ "https://fly.storage.tigris.dev/panic-invocation-outputs"
      assert url =~ Path.basename(tmp_file)

      # Ensure our stub was actually invoked
      assert Repatch.called?(Req, :put, 2)

      File.rm!(tmp_file)
    end
  end
end
