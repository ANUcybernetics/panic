defmodule Panic do
  @moduledoc """
  Panic keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @doc """
  Triggers a test crash for Tower error reporting.

  This function spawns a background process that crashes after 1 second,
  allowing Tower to catch and report the error via email. This is useful
  for testing error notifications in production via a remote IEx shell.

  ## Examples

      iex> Panic.trigger_test_crash()
      :ok
      # Error happens in background process after 1 second

  """
  def trigger_test_crash do
    IO.puts("\n🚨 Triggering test crash in background process...")
    IO.puts("Check for error notification in a few seconds.\n")

    Task.start(fn ->
      # Wait 1 second to make it clearly async
      Process.sleep(1000)
      timestamp = DateTime.to_string(DateTime.utc_now())
      raise "[PANIC TEST] Tower error notification test triggered at #{timestamp}"
    end)

    :ok
  end
end
