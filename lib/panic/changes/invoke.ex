defmodule Panic.Changes.Invoke do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.fetch_change(changeset, :input) do
      {:ok, _input} ->
        network = changeset.arguments.network
        models = network.models

        if length(models) == 0 do
          Ash.Changeset.add_error(changeset, "No models in network")
        else
          model_index = Integer.mod(changeset.attributes.sequence_number, Enum.count(models))
          model = models |> Enum.at(model_index)

          changeset
          |> Ash.Changeset.change_attribute(:model, model)
          |> Ash.Changeset.manage_relationship(:network, network, type: :append_and_remove)
        end

      :error ->
        changeset
    end
  end
end
