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
  Given an initial input, create a genesis (first in a run) prediction.

  This function will make the call to the relevant model API (based on the
  `:models` field of the network) and return the completed `%Prediction{}`
  object. This might take a while (the API call is synchronous), so call it in a
  `Task` or something if you're worried about blocking.

  If the model API call fails for whatever reason, this will return a changeset
  as usual (with _hopefully_ a more helpful error validation message than the
  usual "can't be blank").

  ## Examples

      iex> create_genesis_prediction("this is a text input prompt", %Network{}, tokens)
      {:ok, %Prediction{}}

      ## if any of the arguments are invalid
      iex> create_genesis_prediction(12345, %Network{}, tokens)
      {:error, %Ecto.Changeset{}}

      ## if the platform API call fails for some reason
      iex> create_genesis_prediction("valid text input", %Network{}, tokens)
      {:platform_error, reason}

  """
  def create_genesis_prediction(input, %Network{} = network, tokens) when is_binary(input) do
    changeset = Prediction.genesis_changeset(input, network)

    case changeset do
      # if the only error is the missing output, make the API call
      %{errors: [output: _]} ->
        case Panic.Platforms.api_call(changeset.changes.model, changeset.changes.input, tokens) do
          {:ok, output} ->
            {:ok, %Prediction{id: id} = prediction} =
              changeset
              |> Prediction.add_output(output)
              |> Repo.insert()

            prediction
            |> Repo.preload([:network])
            |> update_prediction(%{genesis_id: id})

          {:error, :nsfw} ->
            create_genesis_prediction(
              "You have been a bad user. This incident has been reported.",
              network,
              tokens
            )
        end

      # otherwise just return the error changeset
      _ ->
        {:error, changeset}
    end
  end

  @doc """
  Given a prediction, creates the next one in the Run.

  This function will make the call to the relevant model API (based on the
  `:models` field of the network) and return the completed `%Prediction{}`
  object. This might take a while (the API call is synchronous), so call it in a
  `Task` or something if you're worried about blocking.

  If the model API call fails for whatever reason, this will return a changeset
  as usual (with _hopefully_ a more helpful error validation message than the
  usual "can't be blank").

  ## Examples

      iex> create_next_prediction(%Prediction{}, tokens)
      {:ok, %Prediction{}}

      ## if any of the arguments are invalid
      iex> create_next_prediction(nil, tokens)
      {:error, %Ecto.Changeset{}}

      ## if the platform API call fails for some reason
      iex> create_next_prediction(%Prediction{}, tokens)
      {:platform_error, reason}

  """
  def create_next_prediction(%Prediction{} = previous_prediction, tokens) do
    changeset = Prediction.next_changeset(previous_prediction)

    case changeset do
      # if the only error is the missing output, make the API call
      %{errors: [output: _]} ->
        case Panic.Platforms.api_call(changeset.changes.model, changeset.changes.input, tokens) do
          {:ok, output} ->
            {:ok, prediction} =
              changeset
              |> Prediction.add_output(output)
              |> Repo.insert()

            {:ok, Repo.preload(prediction, [:network])}

          {:error, :nsfw} ->
            create_genesis_prediction(
              "You have been a bad user. This incident has been reported.",
              previous_prediction.network,
              tokens
            )
        end

      # otherwise just return the error changeset
      _ ->
        {:error, changeset}
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
