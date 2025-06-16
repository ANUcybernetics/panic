defmodule Panic.Engine.Changes.PrepareNext do
  @moduledoc """
  Change module for preparing the next invocation in a network run.

  This change:
  1. Gets the previous invocation and its network
  2. Calculates the next model in the sequence (cycling through the models array)
  3. Sets the model, run_number, sequence_number, and input based on the previous invocation
  4. Associates the invocation with the network
  """
  use Ash.Resource.Change

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def change(changeset, _opts, context) do
    case Ash.Changeset.fetch_argument(changeset, :previous_invocation) do
      {:ok, previous_invocation} ->
        prepare_next_invocation(changeset, previous_invocation, context)

      :error ->
        Ash.Changeset.add_error(changeset, "missing :previous_invocation argument")
    end
  end

  defp prepare_next_invocation(changeset, previous_invocation, context) do
    %{
      network: %{models: models} = network,
      run_number: run_number,
      sequence_number: prev_sequence_number,
      output: prev_output
    } = Ash.load!(previous_invocation, :network, actor: context.actor)

    model_index = Integer.mod(prev_sequence_number + 1, Enum.count(models))
    model = Enum.at(models, model_index)

    changeset
    |> Ash.Changeset.force_change_attribute(:model, model)
    |> Ash.Changeset.force_change_attribute(:run_number, run_number)
    |> Ash.Changeset.force_change_attribute(:sequence_number, prev_sequence_number + 1)
    |> Ash.Changeset.force_change_attribute(:input, prev_output)
    |> Ash.Changeset.manage_relationship(:network, network, type: :append_and_remove)
  end
end
