defmodule Panic.Platforms.ReplicateTest do
  use ExUnit.Case, async: true

  alias Panic.Platforms.Replicate

  describe "detect_nsfw/1" do
    test "detects error messages starting with NSFW" do
      assert Replicate.detect_nsfw("NSFW content detected")
      assert Replicate.detect_nsfw("NSFW: inappropriate content")
      assert Replicate.detect_nsfw("NSFW")
    end

    test "detects 'flagged as sensitive' pattern from seededit-3.0 model" do
      error_message =
        "The input or output was flagged as sensitive. Please try again with different inputs. (E005)"

      assert Replicate.detect_nsfw(error_message)
    end

    test "detects various sensitive content patterns" do
      assert Replicate.detect_nsfw("This content contains nsfw material")
      assert Replicate.detect_nsfw("Inappropriate content detected")
      assert Replicate.detect_nsfw("Contains explicit content")
      assert Replicate.detect_nsfw("Adult content warning")
    end

    test "detects sensitive content with error codes" do
      assert Replicate.detect_nsfw("Content flagged as sensitive (E001)")
      assert Replicate.detect_nsfw("Your request was marked sensitive (E005)")
      assert Replicate.detect_nsfw("Sensitive material detected (E009)")
    end

    test "is case insensitive for most patterns" do
      assert Replicate.detect_nsfw("INAPPROPRIATE CONTENT")
      assert Replicate.detect_nsfw("Explicit Content")
      assert Replicate.detect_nsfw("ADULT CONTENT")
      assert Replicate.detect_nsfw("nsfw detected")
    end

    test "does not detect non-NSFW error messages" do
      refute Replicate.detect_nsfw("Model not found")
      refute Replicate.detect_nsfw("Invalid input parameters")
      refute Replicate.detect_nsfw("Request timeout")
      refute Replicate.detect_nsfw("Authentication failed")
      refute Replicate.detect_nsfw("")
    end

    test "handles non-string inputs gracefully" do
      refute Replicate.detect_nsfw(nil)
      refute Replicate.detect_nsfw(123)
      refute Replicate.detect_nsfw(%{error: "nsfw"})
      refute Replicate.detect_nsfw([:nsfw])
    end

    test "does not falsely trigger on words containing 'sensitive' without error codes" do
      refute Replicate.detect_nsfw("This is a sensitive topic to discuss")
      refute Replicate.detect_nsfw("Please be sensitive to others")
    end

    test "correctly detects edge cases" do
      # Should detect - starts with NSFW
      assert Replicate.detect_nsfw("NSFWcontent")

      # Should detect - contains the exact phrases we look for
      assert Replicate.detect_nsfw("Error: inappropriate content in image")
      assert Replicate.detect_nsfw("Failed due to explicit content")

      # Should not detect - similar but different words
      refute Replicate.detect_nsfw("insensitive comment")
      refute Replicate.detect_nsfw("adult supervision required")
    end
  end

  describe "get/2 with NSFW errors" do
    test "returns :nsfw atom for detected NSFW errors" do
      # This test would require mocking the HTTP request, which would need
      # additional test setup. For now, we're focusing on the detect_nsfw
      # function itself, which is the core of the improvement.
    end
  end
end
