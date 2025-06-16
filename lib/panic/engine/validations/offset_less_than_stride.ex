defmodule Panic.Engine.Validations.OffsetLessThanStride do
  @moduledoc """
  Validation module for ensuring that offset is less than stride for single and vestaboard watcher types.

  This validation checks that for watcher types :single and :vestaboard, the offset value
  must be less than the stride value to ensure proper cycling behavior.
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def validate(changeset, _opts, _context) do
    case {Ash.Changeset.get_attribute(changeset, :type), Ash.Changeset.get_attribute(changeset, :stride),
          Ash.Changeset.get_attribute(changeset, :offset)} do
      {type, stride, offset}
      when type in [:single, :vestaboard] and
             is_integer(stride) and
             is_integer(offset) and
             offset >= stride ->
        {:error, field: :offset, message: "offset must be less than stride"}

      _ ->
        :ok
    end
  end
end
