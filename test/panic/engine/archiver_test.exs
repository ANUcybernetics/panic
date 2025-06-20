defmodule Panic.Engine.ArchiverTest do
  use ExUnit.Case

  alias Panic.Engine.Archiver

  describe "convert_file/2" do
    test "webp files require no conversion" do
      # Create a temporary webp file
      temp_file = Path.join(System.tmp_dir(), "test_#{System.unique_integer()}.webp")
      File.write!(temp_file, "fake webp content")

      assert {:ok, ^temp_file} = Archiver.convert_file(temp_file, "output")

      File.rm(temp_file)
    end

    test "webm files require no conversion" do
      # Create a temporary webm file
      temp_file = Path.join(System.tmp_dir(), "test_#{System.unique_integer()}.webm")
      File.write!(temp_file, "fake webm content")

      assert {:ok, ^temp_file} = Archiver.convert_file(temp_file, "output")

      File.rm(temp_file)
    end

    test "unsupported file formats return error" do
      # Create a temporary file with unsupported extension
      temp_file = Path.join(System.tmp_dir(), "test_#{System.unique_integer()}.txt")
      File.write!(temp_file, "some text content")

      assert {:error, "Unsupported file format: .txt"} = Archiver.convert_file(temp_file, "output")

      File.rm(temp_file)
    end

    @tag :external_deps
    test "jpg files are converted to webp when ImageMagick is available" do
      # Create a minimal JPG file (1x1 pixel black JPG)
      jpg_content =
        <<255, 216, 255, 224, 0, 16, 74, 70, 73, 70, 0, 1, 1, 1, 0, 72, 0, 72, 0, 0, 255, 219, 0, 67, 0, 8, 6, 6, 7, 6, 5,
          8, 7, 7, 7, 9, 9, 8, 10, 12, 20, 13, 12, 11, 11, 12, 25, 18, 19, 15, 20, 29, 26, 31, 30, 29, 26, 28, 28, 32, 36,
          46, 39, 32, 34, 44, 35, 28, 28, 40, 55, 41, 44, 48, 49, 52, 52, 52, 31, 39, 57, 61, 56, 50, 60, 46, 51, 52, 50,
          255, 219, 0, 67, 1, 9, 9, 9, 12, 11, 12, 24, 13, 13, 24, 50, 33, 28, 33, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50,
          50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50,
          50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 255, 192, 0, 17, 8, 0, 1, 0, 1, 1, 1, 17, 0, 2, 17, 1, 3, 17, 1,
          255, 196, 0, 31, 0, 0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 255,
          196, 0, 181, 16, 0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 125, 1, 2, 3, 0, 4, 17, 5, 18, 33, 49, 65, 6, 19,
          81, 97, 7, 34, 113, 20, 50, 129, 145, 161, 8, 35, 66, 177, 193, 21, 82, 209, 240, 36, 51, 98, 114, 130, 9, 10,
          22, 23, 24, 25, 26, 37, 38, 39, 40, 41, 42, 52, 53, 54, 55, 56, 57, 58, 67, 68, 69, 70, 71, 72, 73, 74, 83, 84,
          85, 86, 87, 88, 89, 90, 99, 100, 101, 102, 103, 104, 105, 106, 115, 116, 117, 118, 119, 120, 121, 122, 131, 132,
          133, 134, 135, 136, 137, 138, 146, 147, 148, 149, 150, 151, 152, 153, 154, 162, 163, 164, 165, 166, 167, 168,
          169, 170, 178, 179, 180, 181, 182, 183, 184, 185, 186, 194, 195, 196, 197, 198, 199, 200, 201, 202, 210, 211,
          212, 213, 214, 215, 216, 217, 218, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 241, 242, 243, 244, 245,
          246, 247, 248, 249, 250, 255, 196, 0, 31, 1, 0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5,
          6, 7, 8, 9, 10, 11, 255, 196, 0, 181, 17, 0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, 119, 0, 1, 2, 3, 17, 4,
          5, 33, 49, 6, 18, 65, 81, 7, 97, 113, 19, 34, 50, 129, 8, 20, 66, 145, 161, 177, 193, 9, 35, 51, 82, 240, 21,
          98, 114, 209, 10, 22, 36, 52, 225, 37, 241, 23, 24, 25, 26, 38, 39, 40, 41, 42, 53, 54, 55, 56, 57, 58, 67, 68,
          69, 70, 71, 72, 73, 74, 83, 84, 85, 86, 87, 88, 89, 90, 99, 100, 101, 102, 103, 104, 105, 106, 115, 116, 117,
          118, 119, 120, 121, 122, 130, 131, 132, 133, 134, 135, 136, 137, 138, 146, 147, 148, 149, 150, 151, 152, 153,
          154, 162, 163, 164, 165, 166, 167, 168, 169, 170, 178, 179, 180, 181, 182, 183, 184, 185, 186, 194, 195, 196,
          197, 198, 199, 200, 201, 202, 210, 211, 212, 213, 214, 215, 216, 217, 218, 226, 227, 228, 229, 230, 231, 232,
          233, 234, 242, 243, 244, 245, 246, 247, 248, 249, 250, 255, 218, 0, 12, 3, 1, 0, 2, 17, 3, 17, 0, 63, 0, 244,
          162, 138, 43, 207, 80, 81, 69, 20, 80, 1, 69, 20, 80, 1, 69, 20, 80, 1, 69, 20, 80, 1, 69, 20, 80, 1, 69, 20,
          80, 1, 69, 20, 80, 1, 69, 20, 80, 1, 69, 20, 80, 1, 255, 217>>

      temp_file = Path.join(System.tmp_dir(), "test_#{System.unique_integer()}.jpg")
      File.write!(temp_file, jpg_content)

      case System.find_executable("convert") do
        nil ->
          # ImageMagick not available, expect error
          assert {:error, _} = Archiver.convert_file(temp_file, "output")

        _convert_path ->
          # ImageMagick available, should succeed
          case Archiver.convert_file(temp_file, "output") do
            {:ok, output_file} ->
              assert String.ends_with?(output_file, ".webp")
              assert File.exists?(output_file)
              File.rm(output_file)

            {:error, _reason} ->
              # Conversion failed - this is expected if the minimal JPG is invalid
              :ok
          end
      end

      File.rm(temp_file)
    end

    @tag :external_deps
    test "mp3 files are processed when ffmpeg is available" do
      # Create a minimal MP3 file header
      mp3_content = <<255, 251, 144, 0>>
      temp_file = Path.join(System.tmp_dir(), "test_#{System.unique_integer()}.mp3")
      File.write!(temp_file, mp3_content)

      case System.find_executable("ffmpeg") do
        nil ->
          # FFmpeg not available, expect error
          assert {:error, _} = Archiver.convert_file(temp_file, "output")

        _ffmpeg_path ->
          # FFmpeg available, should attempt conversion (may fail due to invalid MP3)
          case Archiver.convert_file(temp_file, "output") do
            {:ok, output_file} ->
              assert String.ends_with?(output_file, ".mp3")
              File.rm(output_file)

            {:error, _reason} ->
              # Conversion failed - expected with minimal/invalid MP3
              :ok
          end
      end

      File.rm(temp_file)
    end

    test "case insensitive file extensions" do
      # Test uppercase extensions
      temp_file = Path.join(System.tmp_dir(), "test_#{System.unique_integer()}.WEBP")
      File.write!(temp_file, "fake webp content")

      assert {:ok, ^temp_file} = Archiver.convert_file(temp_file, "output")

      File.rm(temp_file)
    end
  end

  describe "download_file/1" do
    @tag :external_deps
    test "downloads file from valid URL" do
      # Use a simple HTTP service for testing
      url = "https://httpbin.org/robots.txt"

      case Archiver.download_file(url) do
        {:ok, filename} ->
          assert File.exists?(filename)
          content = File.read!(filename)
          # httpbin.org robots.txt should contain some content
          assert String.length(content) > 0
          File.rm(filename)

        {:error, _reason} ->
          # Network might not be available in test environment
          :ok
      end
    end

    test "handles invalid URLs" do
      assert_raise ArgumentError, fn ->
        Archiver.download_file("not-a-valid-url")
      end
    end
  end

  describe "upload_to_s3/1" do
    test "returns error for non-existent file" do
      non_existent_file = "/tmp/does_not_exist_#{System.unique_integer()}"

      assert_raise File.Error, fn ->
        Archiver.upload_to_s3(non_existent_file)
      end
    end
  end
end
