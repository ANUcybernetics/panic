defmodule Panic do
  @moduledoc """
  Panic keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @doc """
  Triggers a test crash for Tower error reporting.
  
  This function is intended for testing error notifications in production
  via a remote IEx shell. It will raise an error that Tower should catch
  and send via email.
  
  ## Examples
  
      iex> Panic.trigger_test_crash()
      ** (RuntimeError) [PANIC TEST] Tower error notification test triggered at 2024-...
  
  """
  def trigger_test_crash do
    timestamp = DateTime.utc_now() |> DateTime.to_string()
    error_message = "[PANIC TEST] Tower error notification test triggered at #{timestamp}"
    
    IO.puts("\n🚨 Triggering test crash for Tower error reporting...")
    IO.puts("Error message: #{error_message}")
    IO.puts("This should generate an email notification.\n")
    
    raise error_message
  end

  @doc """
  Triggers a test crash in a spawned process.
  
  This tests that Tower can catch errors from background processes,
  not just the main IEx shell process.
  
  ## Examples
  
      iex> Panic.trigger_async_test_crash()
      :ok
      # Error happens in background process
  
  """
  def trigger_async_test_crash do
    IO.puts("\n🚨 Triggering async test crash in background process...")
    IO.puts("Check for error notification in a few seconds.\n")
    
    Task.start(fn ->
      Process.sleep(1000)  # Wait 1 second to make it clearly async
      timestamp = DateTime.utc_now() |> DateTime.to_string()
      raise "[PANIC ASYNC TEST] Background process error at #{timestamp}"
    end)
    
    :ok
  end
end
