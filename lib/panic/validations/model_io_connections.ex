defmodule Panic.Validations.ModelIOConnections do
  @moduledoc """
  This module provides a custom validation for checking the compatibility
  of input and output types in a sequence of models within a network.
  It ensures that the output type of each model matches the input type
  of the subsequent model, and that the network forms a valid cycle.

  The empty network (i.e. models == []) is considered invalid.
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

  def network_runnable?([]), do: {:error, "empty network cannot be run"}

  def network_runnable?(models) do
    # validate that each "interface" matches
    models
    |> Enum.map(fn model_id ->
      %{name: name, input_type: input, output_type: output} = Panic.Model.by_id!(model_id)
      {name, input, output}
    end)
    # hack to ensure first input is :text
    |> List.insert_at(0, {"Initial input", nil, :text})
    |> List.insert_at(-1, {"Final (loopback) output", :text, nil})
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce([], fn [{name_1, _, output_type}, {name_2, input_type, _}], errors ->
      if output_type == input_type do
        errors
      else
        [
          "#{name_1} output (#{output_type}) does not match #{name_2} input (#{input_type})"
          | errors
        ]
      end
    end)
    |> case do
      [] ->
        :ok

      error_string ->
        {:error, error_string |> Enum.reverse() |> Enum.join(", ")}
    end
  end
end
