defmodule Panic.Engine.Changes.InvokeModel do
  @moduledoc """
  Calls the invocation's model and records the outcome.

  1. Before the transaction, the invocation is marked `:invoking` (so watchers
     see it start) and the model is called, which can take minutes, so it
     must not hold SQLite's write lock. A successful call then waits until
     `hold_until`, if it's set, so the output doesn't appear while a
     Vestaboard is still flipping (see `Panic.Engine.Schedule`).
  2. Inside the transaction, the output and `:completed` state are set, along
     with the usage of each platform call in `metadata["usage"]` and the cost
     and energy estimated from it (see `Panic.Engine.Footprint`), or `:failed`
     if the call failed even after a retry with a safe input (see
     `call_model/1`). A failed call is an outcome, not an action
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
  alias Panic.Engine.Footprint
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
    Panic.Engine.about_to_invoke!(changeset.data, actor: context.actor)

    case call_model(changeset.data) do
      {:ok, output, metadata} ->
        wait_for_hold(changeset.data)
        Ash.Changeset.put_context(changeset, :invocation_result, {:ok, output, metadata})

      {:error, reason} ->
        Ash.Changeset.put_context(changeset, :invocation_result, {:error, reason})
    end
  end

  defp call_model(%{model: model_id, input: input}) do
    with {:model, %Panic.Model{} = model} <- {:model, Panic.Model.by_id(model_id)},
         {:ok, token} <- PlatformCredentials.fetch_token(model.platform) do
      case Panic.Model.invoke(model, input, token) do
        {:ok, output, usage} -> {:ok, output, %{"usage" => usage}}
        {:error, reason} -> retry_with_safe_input(model, reason, token)
      end
    else
      {:model, nil} -> {:error, "Model with ID '#{model_id}' no longer exists"}
      {:error, reason} -> {:error, reason}
    end
  end

  # Models refuse some inputs (safety filters, moderation), and every platform
  # words that differently. Rather than recognise each refusal, any failure is
  # retried once with an input no filter objects to: a refusal recovers and the
  # run carries on, while a real outage fails again and ends the run.
  defp retry_with_safe_input(model, reason, token) do
    with {:ok, output, usage} <- Panic.Model.invoke(model, safe_input(model.input_type), token) do
      {:ok, output, %{"usage" => usage, "error_before_safe_retry" => inspect(reason)}}
    end
  end

  defp wait_for_hold(%{hold_until: hold_until}) do
    hold_until
    |> Schedule.remaining_hold_ms(DateTime.utc_now())
    |> Process.sleep()
  end

  defp record_outcome(changeset) do
    case changeset.context[:invocation_result] do
      {:ok, output, metadata} ->
        footprint = Footprint.estimate(metadata["usage"])

        changeset
        |> Ash.Changeset.force_change_attribute(:output, output)
        |> Ash.Changeset.force_change_attribute(:state, :completed)
        |> Ash.Changeset.force_change_attribute(:cost_usd, footprint.cost_usd)
        |> Ash.Changeset.force_change_attribute(:energy_wh, footprint.energy_wh)
        |> Ash.Changeset.force_change_attribute(
          :metadata,
          Map.merge(changeset.data.metadata, metadata)
        )

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
    %{current_run_number: current} =
      Panic.Engine.get_network!(invocation.network_id, authorize?: false)

    current == invocation.run_number
  end

  @safe_inputs %{
    text: "a wombat holding a sign that says 'whoops!'",
    image: "https://fly.storage.tigris.dev/panic-invocation-outputs/nsfw-placeholder.webp",
    audio: "https://fly.storage.tigris.dev/panic-invocation-outputs/test-audio.ogg"
  }

  @doc false
  def safe_input(input_type), do: Map.fetch!(@safe_inputs, input_type)
end
