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
     if the model failed and nothing could recover it (see `recover/3`). A
     failed call is an outcome, not an action error, so the trigger job
     doesn't retry a model that rejected its input.
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

  require Logger

  @impl true
  def change(changeset, _opts, context) do
    changeset
    |> Ash.Changeset.before_transaction(&invoke(&1, context))
    |> Ash.Changeset.before_action(&record_outcome/1)
    |> Ash.Changeset.after_action(&emit_outcome/2)
  end

  defp invoke(changeset, context) do
    Panic.Engine.about_to_invoke!(changeset.data, actor: context.actor)

    result =
      case Panic.Model.by_id(changeset.data.model) do
        nil ->
          {:error, "Model with ID '#{changeset.data.model}' no longer exists"}

        model ->
          with {:error, reason} <- call(model, changeset.data.input) do
            recover(model, changeset.data, reason)
          end
      end

    if match?({:ok, _, _, _}, result), do: wait_for_hold(changeset.data)
    Ash.Changeset.put_context(changeset, :invocation_result, result)
  end

  defp call(model, input) do
    with {:ok, token} <- PlatformCredentials.fetch_token(model.platform),
         {:ok, output, usage} <- Panic.Model.invoke(model, input, token) do
      {:ok, output, %{"usage" => usage}, model.id}
    end
  end

  # The show must go on: when a model fails (an outage, a hung prediction, a
  # refusal, which every platform words differently), the run carries on with
  # the first of these that works:
  #
  # 1. a stand-in model of the same types (`Panic.Model.stand_in/1`) on the
  #    same input, which the invocation then records as its model
  # 2. the run's latest output of the model's output type, which needs no
  #    platform at all
  # 3. the model on an input no filter objects to, for when there's nothing to
  #    reuse yet
  #
  # Only when all three fail does the invocation fail and the run end.
  defp recover(model, invocation, reason) do
    recovered =
      with {:error, _} <- stand_in(model, invocation.input),
           {:error, _} <- reuse(model, invocation) do
        safe_retry(model)
      end

    case recovered do
      {:ok, output, metadata, model_id} ->
        Logger.warning("#{model.id} failed (#{inspect(reason)}), recovered by #{recovery(metadata, model_id)}")

        {:ok, output, Map.put(metadata, "recovered_from", inspect(reason)), model_id}

      {:error, _} ->
        {:error, reason}
    end
  end

  defp stand_in(model, input) do
    case Panic.Model.stand_in(model) do
      nil ->
        {:error, :no_stand_in}

      stand_in ->
        with {:ok, output, metadata, id} <- call(stand_in, input) do
          {:ok, output, Map.put(metadata, "stood_in_for", model.id), id}
        end
    end
  end

  defp reuse(%{output_type: type} = model, invocation) do
    invocation.network_id
    |> Panic.Engine.completed_before!(invocation.run_number, invocation.sequence_number, authorize?: false)
    |> Enum.find(&match?(%{output_type: ^type}, Panic.Model.by_id(&1.model)))
    |> case do
      nil ->
        {:error, :nothing_to_reuse}

      earlier ->
        {:ok, earlier.output, %{"usage" => [], "reused_output_of" => earlier.id}, model.id}
    end
  end

  defp safe_retry(model) do
    with {:ok, output, metadata, id} <- call(model, safe_input(model.input_type)) do
      {:ok, output, Map.put(metadata, "safe_input", true), id}
    end
  end

  defp recovery(%{"stood_in_for" => _}, model_id), do: "standing in #{model_id}"

  defp recovery(%{"reused_output_of" => id}, _model_id), do: "reusing the output of invocation #{id}"

  defp recovery(%{"safe_input" => true}, _model_id), do: "a safe input"

  defp wait_for_hold(%{hold_until: hold_until}) do
    hold_until
    |> Schedule.remaining_hold_ms(DateTime.utc_now())
    |> Process.sleep()
  end

  defp record_outcome(changeset) do
    case changeset.context[:invocation_result] do
      {:ok, output, metadata, model_id} ->
        footprint = Footprint.estimate(metadata["usage"])

        changeset
        |> Ash.Changeset.force_change_attribute(:model, model_id)
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

  # The image is priv/static/images/technical-difficulties.webp, a wombat's
  # take on The Simpsons' "technical difficulties" card; the text describes it.
  @safe_inputs %{
    text:
      "A sheepish wombat sits in a tangle of chewed-through TV cables, a sparking wire " <>
        "in its mouth, in front of a retro test card under the words " <>
        "'TECHNICAL DIFFICULTIES, PLEASE STAND BY'",
    image: "https://fly.storage.tigris.dev/panic-invocation-outputs/technical-difficulties.webp",
    audio: "https://fly.storage.tigris.dev/panic-invocation-outputs/test-audio.ogg"
  }

  @doc false
  def safe_input(input_type), do: Map.fetch!(@safe_inputs, input_type)
end
