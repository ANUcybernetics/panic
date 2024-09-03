defmodule Panic.Workers.Invoker do
  use Oban.Worker, queue: :default

  alias Panic.Engine

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"invocation_id" => invocation_id}}) do
    with {:ok, invocation} <- Ash.get(Panic.Engine.Invocation, invocation_id),
         {:ok, network} <- Ash.get(Panic.Engine.Network, invocation.network_id),
         {:ok, invoked_invocation} <- Panic.Engine.invoke(invocation),
         :ok <- maybe_schedule_next_invocation(network, invoked_invocation) do
      :ok
    end
  end

  defp maybe_schedule_next_invocation(network, invocation) do
    if network.state in [:running, :starting] do
      case Engine.prepare_next(previous_invocation: invocation) do
        {:ok, next_invocation} ->
          schedule_next_invocation(next_invocation)

        {:error, reason} ->
          {:error, reason}
      end
    else
      :ok
    end
  end

  defp schedule_next_invocation(next_invocation) do
    %{invocation_id: next_invocation.id}
    |> __MODULE__.new()
    |> Oban.insert()
    |> case do
      {:ok, _job} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
