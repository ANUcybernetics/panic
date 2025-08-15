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
    # Get the original models from the data
    old_models = changeset.data.models || []

    # Try to get the new value from the changeset
    new_models = Ash.Changeset.get_attribute(changeset, :models)

    # If models is nil, it means it's not being set - this shouldn't happen
    # with our update_models action but let's handle it
    if is_nil(new_models) do
      # This should only happen if the attribute is not being set at all
      # In that case, validate the current state
      case network_runnable?(old_models) do
        :ok -> :ok
        {:error, message} -> {:error, message: message, field: :models}
      end
    else
      # Allow transition from empty to non-empty (initial network setup)
      # This allows newly created networks to be populated with their first set of models
      if old_models == [] and new_models != [] do
        case network_runnable?(new_models) do
          :ok -> :ok
          {:error, message} -> {:error, message: message, field: :models}
        end
      else
        # For all other cases, apply normal validation
        case network_runnable?(new_models) do
          :ok -> :ok
          {:error, message} -> {:error, message: message, field: :models}
        end
      end
    end
  end

  def network_runnable?(model_ids) do
    # Convert model ids to {name, input_type, output_type} tuples
    # Handle missing models gracefully
    {model_tuples, missing_ids} =
      Enum.reduce(model_ids, {[], []}, fn id, {tuples, missing} ->
        case Panic.Model.by_id(id) do
          nil ->
            {tuples, [id | missing]}
          %{name: name, input_type: input, output_type: output} ->
            {[{name, input, output} | tuples], missing}
        end
      end)
    
    model_tuples = Enum.reverse(model_tuples)
    missing_ids = Enum.reverse(missing_ids)
    
    # If there are missing models, return error immediately
    if missing_ids != [] do
      {:error, "Network contains models that no longer exist: #{Enum.join(missing_ids, ", ")}"}
    else

    if model_tuples == [] do
      {:error, "network must contain at least one model"}
    else
      # Prepend the initial text input sentinel so the first model's input is checked
      sequential_errors =
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

      # Check if the network forms a valid cycle (last output -> first input)
      {first_name, first_input, _} = List.first(model_tuples)
      {last_name, _, last_output} = List.last(model_tuples)

      cycle_errors =
        if last_output == first_input do
          []
        else
          [
            "Network doesn't form a valid cycle: #{last_name} output (#{last_output}) doesn't match #{first_name} input (#{first_input})"
          ]
        end

      case sequential_errors ++ cycle_errors do
        [] -> :ok
        errs -> {:error, errs |> Enum.reverse() |> Enum.join(", ")}
      end
    end
    end
  end
end
