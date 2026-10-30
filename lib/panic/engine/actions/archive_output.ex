defmodule Panic.Engine.Actions.ArchiveOutput do
  @moduledoc """
  Archives an image or audio output to S3 when an invocation completes (the
  `:archive_output` action listens to `:invocation_completed` in a job, so a
  failed download or upload is retried).

  Model outputs are often short-lived URLs, so the invocation's output and the
  next invocation's input are both rewritten to point at the archived copy.
  """
  use Ash.Resource.Actions.Implementation

  alias Panic.Engine
  alias Panic.Engine.Archiver

  @impl true
  def run(input, _opts, _context) do
    %{invocation_id: id, run_number: run_number, sequence_number: seq} = input.arguments.signal
    invocation = Engine.get_invocation!(id, authorize?: false)

    if archivable?(invocation) do
      next = Engine.get_invocation_in_run!(run_number, seq + 1, authorize?: false)

      case Archiver.archive_invocation(invocation, next) do
        :ok -> :ok
        {:error, reason} -> {:error, reason}
      end
    else
      :ok
    end
  end

  defp archivable?(%{model: model_id}) do
    case Panic.Model.by_id(model_id) do
      %{output_type: type} -> type in [:image, :audio]
      nil -> false
    end
  end
end
