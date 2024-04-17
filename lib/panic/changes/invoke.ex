defmodule Panic.Changes.Invoke do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.fetch_change(changeset, :input) do
      {:ok, _input} ->
        network = changeset.arguments.network
        models = network.models

        model_index = Integer.mod(changeset.attributes.sequence_number, Enum.count(models))
        model = models |> Enum.at(model_index)

        changeset =
          changeset
          |> Ash.Changeset.change_attribute(:model, model)
          |> Ash.Changeset.manage_relationship(:network, network, type: :append_and_remove)

        # then fire off the Oban job, which will finalise when done

        changeset

      :error ->
        changeset
    end
  end
end
