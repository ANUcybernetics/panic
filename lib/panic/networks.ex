defmodule Panic.Networks do
  @moduledoc """
  The Networks context.
  """

  import Ecto.Query, warn: false
  alias Panic.Repo

  alias Panic.Networks.Network
  alias Panic.Accounts.User

  @doc """
  Returns the list of networks for a given user.

  ## Examples

      iex> list_networks(%User{})
      [%Network{}, ...]

  """
  def list_networks(%User{id: user_id}) do
    Repo.all(from n in Network, where: n.user_id == ^user_id)
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
  Helper function for appending a model to the network's model array.
  """
  def append_model(%Network{models: models} = network, model) do
    update_network(network, %{models: models ++ [model]})
  end

  @doc """
  Helper function for removing the final model in the network's model array.

  This is the opposite of `append_model/2`.
  """
  def remove_last_model(%Network{models: models} = network) do
    update_network(network, %{models: List.delete_at(models, -1)})
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

  ## input prompt is always text
  def last_model_output_type(%Network{models: []}), do: :text

  def last_model_output_type(%Network{models: models}),
    do: models |> List.last() |> Panic.Platforms.model_info() |> Map.get(:output)

  # pubsub helpers
  def subscribe(network_id) do
    Phoenix.PubSub.subscribe(Panic.PubSub, "network:#{network_id}")
  end

  def broadcast(network_id, message) do
    Phoenix.PubSub.broadcast(Panic.PubSub, "network:#{network_id}", message)
  end
end
