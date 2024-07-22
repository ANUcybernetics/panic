defmodule Panic.Model do
  @doc """
  Return the `%Panic.Models.ModelInfo{}` struct for this model.
  """
  @callback info() :: Panic.Models.ModelInfo.t()

  @doc """
  Return `field` from this model's `%Panic.Models.ModelInfo{}` struct.
  """
  @callback fetch!(atom()) :: term()

  @doc """
  Invoke the model with the given input.

  This is a blocking function.
  """
  @callback invoke(String.t()) :: {:ok, String.t()} | {:error, String.t()}
end
