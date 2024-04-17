defmodule Panic.Model do
  @doc """
  Return the model information.
  """
  @callback info() :: Panic.Models.ModelInfo.t()

  @doc """
  Invoke the model with the given input.

  This is a blocking function.
  """
  @callback invoke(String.t()) :: {:ok, String.t()} | {:error, String.t()}
end
