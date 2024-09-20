defmodule Panic.Workers.Invoker do
  @moduledoc """
  An Oban worker module responsible for invoking and queueing panic invocations.

  This module uses Oban to manage the execution of
  invocations---i.e. to call the AI model and get the output.

  This Oban job assumes that the invocation has already been prepared (and is therefore
  in the db) with the `:prepare_next` action on the Invocation resource.

  The "uninterruptible" period (within 30s of run start) is handled by using Oban's
  unique jobs feature, with uniqueness based on network and sequence number (*not* run number).
  So if there's a new first run (`sequence_number == 0`) within 30s of the last one, the Oban
  job insertion will fail with `{:error, :network_not_ready}`.
  """

  # `:period` sets the amount of time to disallow new runs when an existing one has just started
  use Oban.Worker,
    queue: :default,
    unique: [period: 30, keys: [:network_id, :sequence_number]]

  import Ecto.Query

  alias Panic.Engine
  alias Panic.Engine.Invocation

  require Logger

  @doc """
  Performs the invocation job.

  This callback is the implementation of the Oban.Worker behavior. It processes
  the job with the given arguments, invoking the AI model and preparing the next
  invocation if necessary.

  This function shouldn't be called directly; use `insert/2` in this same module
  instead.

  ## Returns
    - :ok if the job is successfully processed.
    - Any error returned by the underlying operations.
  """
  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "user_id" => user_id,
          "invocation_id" => invocation_id,
          "network_id" => _network_id,
          "run_number" => _run_number,
          "sequence_number" => _sequence_number
        }
      }) do
    # IO.puts("Network #{network_id}: invoking #{run_number}-#{sequence_number}")

    # NOTE: authorization is tricky inside the Oban job, because we can only pass ids (well, things that JSON-ify nicely)
    # in as args, so we cheat and pull the user "unauthorized", and then from there we can use that actor (which we need anyway for API tokens)
    with {:ok, user} <- Ash.get(Panic.Accounts.User, user_id, authorize?: false),
         {:ok, invocation} <- Ash.get(Engine.Invocation, invocation_id, actor: user),
         {:ok, invocation} <- Engine.invoke(invocation, actor: user),
         {:ok, next_invocation} <- Engine.prepare_next(invocation, actor: user) do
      insert(next_invocation, user)

      :ok
    end
  end

  @doc """
  Inserts a new Oban job for the given invocation and user.

  This function creates a new Oban job with the provided invocation and user (actor),
  and attempts to insert it into the Oban job queue. It handles potential conflicts
  and returns appropriate results based on the insertion outcome.

  This is really just a wrapper around `Oban.insert` which handles pulling the args out
  of the `invocation` struct, plus returning a more meaningful error on (uniqueness) conflict.

  ## Parameters
    - invocation: The invocation struct containing necessary details.
    - user: The user struct associated with the invocation.

  ## Returns
    - `{:ok, job}` if the job is successfully inserted.
    - `{:error, :network_not_ready}` if there's a conflict with an existing job.
    - `{:error, reason}` for any other insertion errors.
  """
  def insert(invocation, user) do
    %{
      "user_id" => user.id,
      "invocation_id" => invocation.id,
      "network_id" => invocation.network_id,
      "run_number" => invocation.run_number,
      "sequence_number" => invocation.sequence_number
    }
    |> __MODULE__.new()
    |> Oban.insert()
    |> case do
      {:ok, %Oban.Job{conflict?: true}} -> {:error, :network_not_ready}
      {:ok, job} -> {:ok, job}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Cancels all running jobs for a specific network.

  This function retrieves all Oban jobs for the Panic.Workers.Invoker worker
  that are associated with the given network_id and are in a state that allows
  cancellation (scheduled, available, executing, or retryable). It then cancels
  each of these jobs.

  ## Parameters
    - network_id: The ID of the network for which to cancel jobs.

  ## Returns
    - :ok (The function always returns :ok as Enum.each/2 returns :ok)
  """
  def cancel_running_jobs(network_id) do
    from(job in Oban.Job,
      where: job.worker == "Panic.Workers.Invoker",
      where: job.args["network_id"] == ^network_id,
      where: job.state in ["scheduled", "available", "executing", "retryable"]
    )
    |> Panic.Repo.all()
    |> Enum.map(&cancel_job/1)
    |> Enum.count()
    |> then(fn n -> Logger.info("cancelled #{n} jobs for network #{network_id}") end)
  end

  def cancel_running_jobs do
    from(job in Oban.Job,
      where: job.worker == "Panic.Workers.Invoker",
      where: job.state in ["scheduled", "available", "executing", "retryable"]
    )
    |> Panic.Repo.all()
    |> Enum.map(&cancel_job/1)
    |> Enum.count()
    |> then(fn n -> Logger.info("cancelled #{n} jobs") end)
  end

  defp cancel_job(job) do
    Oban.cancel_job(job.id)

    Invocation
    |> Ash.get!(job.args["invocation_id"], authorize?: false)
    |> Panic.Engine.cancel!()
  end
end
