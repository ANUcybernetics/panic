defmodule Panic.Workers.Invoker do
  @moduledoc """
  An Oban worker module responsible for invoking and queueing panic invocations.

  This module uses Oban to manage the execution of
  invocations---i.e. to call the AI model and get the output.

  This Oban job assumes that the invocation has already been prepared (and is therefore
  in the db) with the `:prepare_next` action on the Invocation resource.

  The general logic is:
  - check if there's already a running invocation job (i.e. an instance of this worker)
    - if there's not, run the job (call the model and update the invocation) and queue the next job
    - if there is, check if the first invocation in the current run is < 30s old
      - if it is, then return `{:error, :starting}`
      - if it's not, then cancel the currently running job, invoke the new invocation and then queue the next job
  """

  # `:period` sets the amount of time to disallow new runs when an existing one has just started
  use Oban.Worker,
    queue: :default,
    unique: [period: 30, keys: [:network_id, :run_number, :sequence_number]]

  alias Panic.Engine

  import Ecto.Query

  # note: you can get network_id and user_id from the invocation, but passing both makes it easier
  # to query the jobs table
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
    IO.puts("invoking id #{invocation_id}")

    # NOTE: authorization is tricky inside the Oban job, because we can only pass ids (well, things that JSON-ify nicely)
    # in as args, so we cheat and pull the user "unauthorized", and then from there we can use that actor (which we need anyway for API tokens)
    with {:ok, user} <- Ash.get(Panic.Accounts.User, user_id, authorize?: false),
         {:ok, invocation} <- Ash.get(Engine.Invocation, invocation_id, actor: user) do
      invoke_and_queue_next(invocation, user)
    end
  end

  def invoke_and_queue_next(invocation, user) do
    # see note above re: authorization
    invocation = Engine.invoke!(invocation, actor: user)
    next_invocation = Engine.prepare_next!(invocation, actor: user)

    %{
      "user_id" => user.id,
      "invocation_id" => next_invocation.id,
      "network_id" => next_invocation.network_id,
      "run_number" => next_invocation.run_number,
      "sequence_number" => next_invocation.sequence_number
    }
    |> __MODULE__.new()
    |> Oban.insert()
    |> case do
      {:ok, %Oban.Job{conflict?: true}} -> {:error, :network_not_ready}
      {:ok, _job} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def cancel_running_jobs(network_id) do
    Panic.Repo.all(
      from job in Oban.Job,
        where: job.worker == "Panic.Workers.Invoker",
        where: job.args["network_id"] == ^network_id,
        where: job.state in ["scheduled", "available", "executing", "retryable"]
    )
    |> Enum.each(fn job ->
      Oban.cancel_job(job.id)
    end)
  end
end
