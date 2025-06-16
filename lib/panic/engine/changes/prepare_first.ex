defmodule Panic.Engine.Changes.PrepareFirst do
  @moduledoc """
  Change module for preparing the first invocation in a network run.

  This change:
  1. Sets the sequence_number to 0
  2. Sets the model to the first model in the network's models list
  3. Associates the invocation with the network
  4. Sets up an after_action hook to set the run_number to the invocation's id
  """
  use Ash.Resource.Change

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.change_attribute(:sequence_number, 0)
    |> set_model_and_network()
    |> add_run_number_hook()
  end

  defp set_model_and_network(changeset) do
    case Ash.Changeset.fetch_argument(changeset, :network) do
      {:ok, network} ->
        case network.models do
          [] ->
            Ash.Changeset.add_error(changeset, "No models in network")

          [model_id | _] ->
            changeset
            |> Ash.Changeset.force_change_attribute(:model, model_id)
            |> Ash.Changeset.manage_relationship(:network, network, type: :append_and_remove)
        end

      :error ->
        Ash.Changeset.add_error(changeset, "missing :network argument")
    end
  end

  defp add_run_number_hook(changeset) do
    Ash.Changeset.after_action(changeset, fn _changeset, invocation ->
      invocation
      |> Ash.Changeset.for_update(:set_run_number, %{run_number: invocation.id})
      |> Ash.update!(authorize?: false)
      |> then(&{:ok, &1})
    end)
  end
end
