defmodule Panic.Validations.ModelIOConnections do
  @moduledoc """
  This module provides a custom validation for checking the compatibility
  of input and output types in a sequence of models within a network.
  It ensures that the output type of each model matches the input type
  of the subsequent model, and that the network forms a valid cycle.

  The empty network (i.e. models == []) is considered invalid.

  Note: This validation is not atomic because it requires complex business logic
  involving static model data lookups and sequential validation of model chains.
  Actions using this validation must set `require_atomic? false`.
  """

  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    models = Ash.Changeset.get_attribute(changeset, :models)

    case network_runnable?(models) do
      :ok -> :ok
      {:error, message} -> {:error, message: message, field: :models}
    end
  end

  def network_runnable?(model_ids) do
    # Convert model ids to {name, input_type, output_type} tuples
    model_tuples =
      Enum.map(model_ids, fn id ->
        %{name: name, input_type: input, output_type: output} = Panic.Model.by_id!(id)
        {name, input, output}
      end)

    if model_tuples == [] do
      {:error, "network must contain at least one model"}
    else
      # Prepend the initial text input sentinel so the first model's input is checked
      [{"Initial input", :text, :text} | model_tuples]
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.reduce([], fn
        [{name_1, _input_1, output_type_1}, {name_2, input_type_2, _output_2}], errors ->
          if output_type_1 == input_type_2 do
            errors
          else
            [
              "#{name_1} output (#{output_type_1}) does not match #{name_2} input (#{input_type_2})"
              | errors
            ]
          end
      end)
      |> case do
        [] -> :ok
        errs -> {:error, errs |> Enum.reverse() |> Enum.join(", ")}
      end
    end
  end
end
