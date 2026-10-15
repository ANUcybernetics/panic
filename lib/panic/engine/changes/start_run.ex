defmodule Panic.Engine.Changes.StartRun do
  @moduledoc """
  Creates the genesis invocation of a run, replacing whatever the network was
  running unless that run is still within its lockout period.

  The lockout check reads the network inside the action's (immediate)
  transaction, so two runs started at once can't both pass it. After the
  insert, the invocation's id becomes its `run_number`, the network records it
  as the current run, the `:invoke` trigger is scheduled, and `:run_started`
  is emitted, all in the same transaction.
  """
  use Ash.Resource.Change

  alias Panic.Engine.Errors.RunLocked
  alias Panic.Engine.Network
  alias Panic.Engine.Schedule
  alias Panic.Engine.Signals
  alias Panic.Watcher.Vestaboards

  @impl true
  def change(changeset, _opts, context) do
    case Ash.Changeset.fetch_argument(changeset, :network) do
      {:ok, %{models: [first_model | _]} = network} ->
        changeset
        |> Ash.Changeset.force_change_attribute(:sequence_number, 0)
        |> Ash.Changeset.force_change_attribute(:model, first_model)
        |> Ash.Changeset.manage_relationship(:network, network, type: :append_and_remove)
        |> Ash.Changeset.before_action(&check_lockout_and_schedule(&1, network.id))
        |> Ash.Changeset.after_action(&begin_run(&1, &2, context.actor))

      {:ok, _network} ->
        Ash.Changeset.add_error(changeset, "No models in network")

      :error ->
        Ash.Changeset.add_error(changeset, "missing :network argument")
    end
  end

  defp check_lockout_and_schedule(changeset, network_id) do
    network = Ash.get!(Network, network_id, authorize?: false, load: [:installations])
    now = DateTime.utc_now()

    case lockout_ends_at(network) do
      %DateTime{} = ends_at ->
        if DateTime.before?(now, ends_at) do
          Ash.Changeset.add_error(changeset, RunLocked.exception(retry_at: ends_at))
        else
          schedule_first(changeset, network, now)
        end

      nil ->
        schedule_first(changeset, network, now)
    end
  end

  defp schedule_first(changeset, network, now) do
    initial_prompt_hold? =
      network.installations
      |> Enum.flat_map(& &1.watchers)
      |> Vestaboards.shows_initial_prompt?()

    Ash.Changeset.force_change_attribute(
      changeset,
      :invoke_after,
      Schedule.first_invoke_after(now, initial_prompt_hold?)
    )
  end

  defp lockout_ends_at(%Network{current_run_number: nil}), do: nil

  defp lockout_ends_at(%Network{run_started_at: started_at, lockout_seconds: lockout_seconds}) do
    DateTime.shift(started_at, second: lockout_seconds)
  end

  defp begin_run(changeset, invocation, actor) do
    invocation =
      invocation
      |> Ash.Changeset.for_update(:set_run_number, %{run_number: invocation.id})
      |> Ash.update!(authorize?: false)

    Network
    |> Ash.get!(invocation.network_id, authorize?: false)
    |> Ash.Changeset.for_update(:begin_run, %{
      current_run_number: invocation.run_number,
      run_started_at: invocation.inserted_at
    })
    |> Ash.update!(authorize?: false)

    AshOban.run_trigger(invocation, :invoke,
      scheduled_at: invocation.invoke_after,
      actor: actor
    )

    with :ok <-
           Ash.Signals.emit(changeset, Signals, :run_started, %{
             invocation_id: invocation.id,
             network_id: invocation.network_id,
             run_number: invocation.run_number,
             input: invocation.input
           }) do
      {:ok, invocation}
    end
  end
end
