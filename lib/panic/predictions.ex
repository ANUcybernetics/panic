defmodule Panic.Predictions do
  @moduledoc """
  The Predictions context.
  """

  import Ecto.Query, warn: false
  alias Panic.Repo

  alias Panic.Predictions.Prediction
  alias Panic.Networks.Network

  @doc """
  Returns the list of predictions for a given `network`.

  Results are ordered by the `:run_index` field

  ## Examples

      iex> list_predictions(%Network{})
      [%Prediction{}, ...]

  """
  def list_predictions(%Network{id: network_id}, limit \\ 100) do
    Repo.all(
      from p in Prediction,
        where: p.network_id == ^network_id,
        order_by: [asc: p.genesis_id, asc: p.run_index],
        limit: ^limit
    )
  end

  @doc """
  Returns the list of predictions for a given `network` and `genesis_id` (i.e.
  all the predictions in a run).

  Results are ordered by the `:run_index` field

  ## Examples

  iex> list_predictions(%Network{}, 15)
  [%Prediction{}, ...]

  """
  def list_predictions_in_run(%Network{id: network_id}, genesis_id)
      when is_integer(genesis_id) do
    Repo.all(
      from p in Prediction,
        where: p.network_id == ^network_id and p.genesis_id == ^genesis_id,
        order_by: [asc: p.run_index]
    )
  end

  @doc """
  Gets a single prediction.

  This function preloads the `:network` association.

  Raises `Ecto.NoResultsError` if the Prediction does not exist.

  ## Examples

      iex> get_prediction!(123)
      %Prediction{}

      iex> get_prediction!(456)
      ** (Ecto.NoResultsError)

  """
  def get_prediction!(id), do: Repo.get!(Prediction, id) |> Repo.preload([:network])

  @doc """
  Complete a %Prediction{} with an input but no output.

  This function will make the call to the relevant model API (based on the
  `:models` field of the network) and return the completed `%Prediction{}`
  object. This might take a while (the API call is synchronous), so call it in a
  `Task` or something if you're worried about blocking.

  """
  def predict(%Prediction{output: nil} = prediction, tokens) do
    case Panic.Platforms.api_call(prediction.model, prediction.input, tokens) do
      {:ok, output} ->
        update_prediction(prediction, %{output: output})

      {:error, :nsfw} ->
        {:ok, prediction} = update_prediction(prediction, %{input: "You have been a bad user. This incident has been reported."})
        predict(prediction, tokens)
    end
  end

  @doc """
  Creates a prediction.

  On success - `{:ok, %Prediction{}}` - the prediction will have the `:network`
  attribute preloaded.

  ## Examples

      iex> create_prediction(%{field: value})
      {:ok, %Prediction{}}

      iex> create_prediction(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_prediction(attrs \\ %{}) do
    %Prediction{}
    |> Prediction.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, prediction} -> {:ok, Repo.preload(prediction, [:network])}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Updates a prediction.

  ## Examples

      iex> update_prediction(prediction, %{field: new_value})
      {:ok, %Prediction{}}

      iex> update_prediction(prediction, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_prediction(%Prediction{} = prediction, attrs) do
    prediction
    |> Prediction.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a prediction.

  ## Examples

      iex> delete_prediction(prediction)
      {:ok, %Prediction{}}

      iex> delete_prediction(prediction)
      {:error, %Ecto.Changeset{}}

  """
  def delete_prediction(%Prediction{} = prediction) do
    Repo.delete(prediction)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking prediction changes.

  ## Examples

      iex> change_prediction(prediction)
      %Ecto.Changeset{data: %Prediction{}}

  """
  def change_prediction(%Prediction{} = prediction, attrs \\ %{}) do
    Prediction.changeset(prediction, attrs)
  end
end
