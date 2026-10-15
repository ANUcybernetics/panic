defmodule Panic.Engine.Changes.PrepareNext do
  @moduledoc """
  Prepares the next invocation of a run when the previous one completes (the
  `:prepare_next` action listens to `:invocation_completed`).

  The next invocation takes the previous output as its input and the next
  model in the network's cycle, and its `:invoke` trigger is scheduled for
  `invoke_after` (see `Panic.Engine.Schedule`), in the same transaction as the
  invocation that completed.
  """
  use Ash.Resource.Change

  alias Panic.Engine.Network
  alias Panic.Engine.Schedule
  alias Panic.Watcher.Vestaboards

  @impl true
  def change(changeset, _opts, context) do
    network_id = Ash.Changeset.get_argument(changeset, :network_id)
    previous = Ash.Changeset.get_argument(changeset, :previous_sequence_number)
    network = Ash.get!(Network, network_id, authorize?: false, load: [:installations])
    sequence_number = previous + 1

    vestaboard_hold? =
      network.installations
      |> Enum.flat_map(& &1.watchers)
      |> Vestaboards.any_shows_output?(previous)

    changeset
    |> Ash.Changeset.force_change_attribute(:model, next_model(network.models, sequence_number))
    |> Ash.Changeset.force_change_attribute(:sequence_number, sequence_number)
    |> Ash.Changeset.force_change_attribute(
      :invoke_after,
      Schedule.next_invoke_after(network.run_started_at, DateTime.utc_now(), vestaboard_hold?)
    )
    |> Ash.Changeset.manage_relationship(:network, network, type: :append_and_remove)
    |> Ash.Changeset.after_action(fn _changeset, invocation ->
      AshOban.run_trigger(invocation, :invoke,
        scheduled_at: invocation.invoke_after,
        actor: context.actor
      )

      {:ok, invocation}
    end)
  end

  defp next_model(models, sequence_number) do
    Enum.at(models, Integer.mod(sequence_number, length(models)))
  end
end
