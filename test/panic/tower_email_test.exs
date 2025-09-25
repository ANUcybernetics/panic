defmodule Panic.TowerEmailTest do
  use ExUnit.Case, async: false

  import Swoosh.TestAssertions

  @moduletag :capture_log

  describe "Tower error reporting" do
    test "reports errors via email when a background task crashes" do
      # Use Task.start instead of Task.async to avoid the test process crashing
      Task.start(fn ->
        raise "Test error for Tower email notification"
      end)

      # Give Tower a moment to process and send the email
      Process.sleep(200)

      # Check that an email was sent via TowerEmail.Mailer
      # The subject format includes [panic] prefix
      assert_email_sent(
        from: {"Panic Error Reporter", "panic@benswift.me"},
        to: "ben@benswift.me",
        subject: ~r/\[panic\]\[test\].*RuntimeError/
      )
    end

    test "manual reporting via Tower.report_exception/2" do
      try do
        raise "Manually reported error"
      rescue
        e ->
          Tower.report_exception(e, __STACKTRACE__)
      end

      # Give Tower a moment to process and send the email
      Process.sleep(100)

      # Check that an email was sent with [panic] prefix
      assert_email_sent(
        from: {"Panic Error Reporter", "panic@benswift.me"},
        to: "ben@benswift.me",
        subject: ~r/\[panic\]\[test\].*RuntimeError/
      )
    end

    test "includes error notification for runtime errors" do
      # Trigger an error with specific message
      Task.start(fn ->
        raise "Specific error message for testing"
      end)

      # Give Tower a moment to process and send the email
      Process.sleep(100)

      # Check that an email was sent
      assert_email_sent(
        from: {"Panic Error Reporter", "panic@benswift.me"},
        to: "ben@benswift.me"
      )
    end

    test "does not report caught exceptions in the main process" do
      # This exception is caught and won't be reported
      try do
        raise "This is caught and handled"
      rescue
        _ -> :ok
      end

      # Give Tower a moment to process (it shouldn't send anything)
      Process.sleep(100)

      # Check that no email was sent
      refute_email_sent()
    end

    test "respects Tower configuration for ignored exceptions" do
      # Save original config
      original_ignored = Application.get_env(:tower, :ignored_exceptions, [])

      # Configure Tower to ignore a specific exception
      defmodule TestIgnoredException do
        @moduledoc false
        defexception message: "This should be ignored"
      end

      Application.put_env(:tower, :ignored_exceptions, [TestIgnoredException])

      # Trigger the ignored exception in a task
      Task.start(fn ->
        raise TestIgnoredException, "This should be ignored"
      end)

      # Give Tower a moment to process
      Process.sleep(100)

      # Check that no email was sent
      refute_email_sent()

      # Restore original config
      Application.put_env(:tower, :ignored_exceptions, original_ignored)
    end
  end

  describe "Panic.trigger_test_crash function" do
    test "trigger_test_crash/0 sends error notification" do
      # Call the crash function
      assert :ok = Panic.trigger_test_crash()

      # Wait for the background task to crash (1s delay) and Tower to process it (100ms)
      Process.sleep(1100)

      # Check that an email was sent with the PANIC test message
      # The subject includes [panic][test] prefix
      assert_email_sent(
        from: {"Panic Error Reporter", "panic@benswift.me"},
        to: "ben@benswift.me",
        subject: ~r/\[panic\]\[test\].*PANIC TEST/
      )
    end
  end
end
