defmodule Panic.Predictions do
  @moduledoc """
  The Predictions context.
  """

  import Ecto.Query, warn: false
  alias Panic.Repo

  alias Panic.Predictions.Prediction

  @doc """
  Returns the list of predictions.

  ## Examples

      iex> list_predictions()
      [%Prediction{}, ...]

  """
  def list_predictions do
    Repo.all(Prediction)
  end

  @doc """
  Gets a single prediction.

  Raises `Ecto.NoResultsError` if the Prediction does not exist.

  ## Examples

      iex> get_prediction!(123)
      %Prediction{}

      iex> get_prediction!(456)
      ** (Ecto.NoResultsError)

  """
  def get_prediction!(id), do: Repo.get!(Prediction, id)

  @doc """
  Creates a prediction.

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
      {:ok, %Prediction{genesis_id: nil} = prediction} ->
        ## must be a first run, so set :genesis_id to :id, then return
        update_prediction(prediction, %{genesis_id: prediction.id})

      {:ok, prediction} ->
        {:ok, prediction}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Creates a "next" prediction - the next one in the run.

  ## Examples

      iex> create_next_prediction(%Prediction{})
      {:ok, %Prediction{}}

  """
  def create_next_prediction(%Prediction{} = prev) do
    prev = Panic.Repo.preload(prev, [:network])
    run_index = prev.run_index + 1
    model = Enum.at(prev.network.models, Integer.mod(run_index, 2))

    create_prediction(%{
      input: prev.output,
      model: model,
      run_index: run_index,
      metadata: %{},
      network_id: prev.network.id
    })
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
