defmodule Panic.Engine.Changes.InvokeModel do
  @moduledoc """
  Calls the invocation's model and records the outcome.

  1. Before the transaction, the invocation is marked `:invoking` (so watchers
     see it start) and the model is called, which can take minutes, so it
     must not hold SQLite's write lock. A successful call then waits until
     `hold_until`, if it's set, so the output doesn't appear while a
     Vestaboard is still flipping (see `Panic.Engine.Schedule`).
  2. Inside the transaction, the output and `:completed` state are set, or
     `:failed` if the call failed. A failed call is an outcome, not an action
     error, so the trigger job doesn't retry a model that rejected its input.
  3. `:invocation_completed` is emitted only while the invocation is still
     part of its network's current run, so a stopped or replaced run doesn't
     continue. `:invocation_failed` is always emitted; its listener ignores
     runs that are no longer current.

  Models are called with the app's platform keys
  (`Panic.Accounts.PlatformCredentials`), whoever started the run.
  """
  use Ash.Resource.Change

  alias Panic.Accounts.PlatformCredentials
  alias Panic.Engine.Network
  alias Panic.Engine.Schedule
  alias Panic.Engine.Signals

  @impl true
  def change(changeset, _opts, context) do
    changeset
    |> Ash.Changeset.before_transaction(&invoke(&1, context))
    |> Ash.Changeset.before_action(&record_outcome/1)
    |> Ash.Changeset.after_action(&emit_outcome/2)
  end

  defp invoke(changeset, context) do
    Ash.update!(changeset.data, %{}, action: :about_to_invoke, actor: context.actor)

    case call_model(changeset.data) do
      {:ok, output} ->
        wait_for_hold(changeset.data)
        Ash.Changeset.put_context(changeset, :invocation_result, {:ok, output})

      {:error, reason} ->
        Ash.Changeset.put_context(changeset, :invocation_result, {:error, reason})
    end
  end

  defp call_model(%{model: model_id, input: input}) do
    with {:model, %Panic.Model{} = model} <- {:model, Panic.Model.by_id(model_id)},
         {:ok, token} <- PlatformCredentials.fetch_token(model.platform) do
      case model.invoke.(model, input, token) do
        # retry an NSFW rejection once with a safe prompt
        {:error, :nsfw} -> model.invoke.(model, nsfw_retry_prompt(), token)
        result -> result
      end
    else
      {:model, nil} -> {:error, "Model with ID '#{model_id}' no longer exists"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp wait_for_hold(%{hold_until: hold_until}) do
    hold_until
    |> Schedule.remaining_hold_ms(DateTime.utc_now())
    |> Process.sleep()
  end

  defp record_outcome(changeset) do
    case changeset.context[:invocation_result] do
      {:ok, output} ->
        changeset
        |> Ash.Changeset.force_change_attribute(:output, output)
        |> Ash.Changeset.force_change_attribute(:state, :completed)

      {:error, reason} ->
        changeset
        |> Ash.Changeset.force_change_attribute(:state, :failed)
        |> Ash.Changeset.force_change_attribute(
          :metadata,
          Map.put(changeset.data.metadata, "error", inspect(reason))
        )
    end
  end

  defp emit_outcome(changeset, %{state: :completed} = invocation) do
    if current_run?(invocation) do
      emit(changeset, :invocation_completed, invocation, %{output: invocation.output})
    else
      {:ok, invocation}
    end
  end

  defp emit_outcome(changeset, %{state: :failed} = invocation) do
    emit(changeset, :invocation_failed, invocation, %{})
  end

  defp emit(changeset, signal, invocation, extra) do
    payload =
      Map.merge(extra, %{
        invocation_id: invocation.id,
        network_id: invocation.network_id,
        run_number: invocation.run_number,
        sequence_number: invocation.sequence_number
      })

    with :ok <- Ash.Signals.emit(changeset, Signals, signal, payload) do
      {:ok, invocation}
    end
  end

  defp current_run?(invocation) do
    %{current_run_number: current} = Ash.get!(Network, invocation.network_id, authorize?: false)
    current == invocation.run_number
  end

  defp nsfw_retry_prompt, do: "a wombat holding a sign that says 'whoops!'"
end
