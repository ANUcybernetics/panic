defmodule Panic.Networks do
  @moduledoc """
  The Networks context.
  """

  import Ecto.Query, warn: false
  alias Panic.Repo

  alias Panic.Networks.Network

  @doc """
  Returns the list of networks.

  ## Examples

      iex> list_networks()
      [%Network{}, ...]

  """
  def list_networks do
    Repo.all(Network)
  end

  @doc """
  Gets a single network.

  Raises `Ecto.NoResultsError` if the Network does not exist.

  ## Examples

      iex> get_network!(123)
      %Network{}

      iex> get_network!(456)
      ** (Ecto.NoResultsError)

  """
  def get_network!(id), do: Repo.get!(Network, id)

  @doc """
  Creates a network.

  ## Examples

      iex> create_network(%{field: value})
      {:ok, %Network{}}

      iex> create_network(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_network(attrs \\ %{}) do
    %Network{}
    |> Network.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a network.

  ## Examples

      iex> update_network(network, %{field: new_value})
      {:ok, %Network{}}

      iex> update_network(network, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_network(%Network{} = network, attrs) do
    network
    |> Network.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a network.

  ## Examples

      iex> delete_network(network)
      {:ok, %Network{}}

      iex> delete_network(network)
      {:error, %Ecto.Changeset{}}

  """
  def delete_network(%Network{} = network) do
    Repo.delete(network)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking network changes.

  ## Examples

      iex> change_network(network)
      %Ecto.Changeset{data: %Network{}}

  """
  def change_network(%Network{} = network, attrs \\ %{}) do
    Network.changeset(network, attrs)
  end

  @doc """
  Add a model to the end of a network's model array
  """
  def append_model(%Network{} = network, model) do
    models = network.models ++ [model]

    network
    |> update_network(%{models: models})
  end

  @doc """
  Reorder models within a network
  """
  def reorder_models(%Network{} = network, initial_index, final_index) do
    {model_to_move, models} = List.pop_at(network.models, initial_index)
    models = List.insert_at(models, final_index, model_to_move)

    network
    |> update_network(%{models: models})
  end

  @doc """
  Reset network model array back to the empty list
  """
  def reset_models(%Network{} = network) do
    network
    |> update_network(%{models: []})
  end
end
