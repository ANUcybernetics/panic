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

  use Oban.Worker, queue: :default

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
          "run_number" => _run_number
        }
      }) do
    # Logger.info("Network #{network_id}: invoking for #{run_number}")

    with {:ok, user} <- Ash.get(Panic.Accounts.User, user_id, authorize?: false),
         {:ok, invocation} <- Ash.get(Engine.Invocation, invocation_id, actor: user) do
      case check_running_jobs(invocation) do
        :no_running_jobs ->
          invoke_and_insert_next(invocation, user)

        :running_job_in_lockout ->
          Logger.info("Recent genesis invocation for network #{invocation.network_id}. Dropping job.")
          {:ok, :dropping}

        {:running_job, job} ->
          Logger.info("Cancelling currently running job for network #{invocation.network_id} and starting new run.")
          cancel_job(job)
          invoke_and_insert_next(invocation, user)
      end
    end
  end

  defp check_running_jobs(invocation) do
    from(job in Oban.Job,
      where: job.worker == "Panic.Workers.Invoker",
      where: job.args["invocation_id"] != ^invocation.id,
      where: job.args["network_id"] == ^invocation.network_id,
      where: job.state in ["scheduled", "available", "executing", "retryable"]
    )
    |> Panic.Repo.all()
    |> case do
      [] ->
        :no_running_jobs

      [running_job] ->
        genesis = Ash.get!(Invocation, running_job.args["run_number"], authorize?: false)

        if DateTime.diff(DateTime.utc_now(), genesis.inserted_at, :second) < 30 do
          :running_job_in_lockout
        else
          {:running_job, running_job}
        end
    end
  end

  defp invoke_and_insert_next(invocation, user) do
    with {:ok, invocation} <- Engine.about_to_invoke(invocation, actor: user),
         {:ok, invocation} <- Engine.invoke(invocation, actor: user),
         {:ok, next_invocation} <- Engine.prepare_next(invocation, actor: user) do
      %{
        "user_id" => user.id,
        "invocation_id" => next_invocation.id,
        "network_id" => next_invocation.network_id,
        "run_number" => next_invocation.run_number
      }
      |> __MODULE__.new()
      |> Oban.insert()
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
    |> tap(fn n -> Logger.info("cancelled #{n} jobs for network #{network_id}") end)
  end

  def cancel_running_jobs do
    from(job in Oban.Job,
      where: job.worker == "Panic.Workers.Invoker",
      where: job.state in ["scheduled", "available", "executing", "retryable"]
    )
    |> Panic.Repo.all()
    |> Enum.map(&cancel_job/1)
    |> Enum.count()
    |> tap(fn n -> Logger.info("cancelled #{n} jobs") end)
  end

  defp cancel_job(job) do
    Oban.cancel_job(job.id)

    Invocation
    |> Ash.get!(job.args["invocation_id"], authorize?: false)
    |> Panic.Engine.cancel!(authorize?: false)
  end
end
