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
  use Oban.Worker, queue: :default
  import Ecto.Query

  alias Panic.Engine

  # note: you can get network_id from the invocation, but passing both makes it easier
  # to query the jobs table
  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "invocation_id" => invocation_id,
          "network_id" => network_id,
          "run_number" => run_number,
          "sequence_number" => _sequence_number
        }
      }) do
    with {:ok, invocation} <- Ash.get(Engine.Invocation, invocation_id, authorize?: false) do
      get_running_jobs(network_id, run_number)
      |> case do
        [] ->
          invoke_and_queue_next(invocation)
          :ok

        [first | _] = run ->
          if DateTime.diff(DateTime.utc_now(), first.inserted_at, :second) > 30 do
            run |> List.last() |> invoke_and_queue_next()
            :ok
          else
            {:cancel, :too_soon}
          end
      end
    end
  end

  def invoke_and_queue_next(invocation) do
    invocation = Engine.invoke!(invocation)
    next_invocation = Engine.prepare_next!(invocation)

    __MODULE__.new(%{
      "invocation_id" => next_invocation.id,
      "network_id" => next_invocation.network_id,
      "run_number" => next_invocation.run_number,
      "sequence_number" => next_invocation.sequence_number
    })
    |> Oban.insert()
    |> case do
      {:ok, _job} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def get_running_jobs(network_id, run_number) do
    Panic.Repo.all(
      from job in Oban.Job,
        where: job.worker == "Panic.Workers.Invoker",
        where: job.args["network_id"] == ^network_id and job.args["run_number"] == ^run_number,
        where: job.state in ["scheduled", "available", "executing", "retryable"],
        order_by: [asc: job.args["sequence_number"]]
    )
  end
end
