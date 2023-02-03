defmodule Panic.Predictions do
  @moduledoc """
  The Predictions context.
  """

  import Ecto.Query, warn: false
  alias Panic.Repo

  alias Panic.Predictions.Prediction
  alias Panic.Networks.Network
  alias Panic.Accounts.User

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

  Unless you're creating a prediction from a "raw" map of attrs, it's probably
  easier to call `create_genesis_prediction/3` (which will hit the API for you,
  plus fix up the genesis block stuff) or `create_next_prediction/3` (again,
  will hit the API and get all the `run_index` stuff right).

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
  end

  @doc """
  Creates a genesis (first in a run) prediction.

  This function will make the call to the relevant model API (based on the
  `:models` field of the network) and return the completed `%Prediction{}`
  object. This might take a while (the API call is synchronous), so call it in a
  `Task` or something if you're worried about blocking.

  If the model API call fails for whatever reason, this will return a changeset
  as usual (with _hopefully_ a more helpful error validation message than the
  usual "can't be blank").

  ## Examples

      iex> create_genesis_prediction("this is a text input prompt", %Network{}, %User{})
      {:ok, %Prediction{}}

      ## if any of the arguments are invalid
      iex> create_genesis_prediction(nil, %Network{}, %User{})
      {:error, %Ecto.Changeset{}}

      ## if the platform API call fails for some reason
      iex> create_genesis_prediction("valid text input", %Network{}, %User{})
      {:platform_error, reason}

  """
  def create_genesis_prediction(input, %Network{} = network, %User{} = user) do
    ## TODO it would be better if this function checked if the changeset were
    ## valid apart from the output before making the API call (to avoid making
    ## the API call if the other params were invalid)
    model = Panic.Networks.model_at_index(network, 0)
    output = Panic.Platforms.api_call(model, input, user)

    %{
      input: input,
      output: output,
      model: model,
      run_index: 0,
      metadata: %{},
      network_id: network.id
    }
    |> create_prediction()
    |> case do
      {:ok, %Prediction{id: id} = prediction} ->
        ## it's a first run, so set :genesis_id to :id
        update_prediction(prediction, %{genesis_id: id})

      {:error, changeset} ->
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

      iex> create_next_prediction(%Prediction{}, %Network{}, %User{})
      {:ok, %Prediction{}}

      ## if any of the arguments are invalid
      iex> create_next_prediction(nil, %Network{}, %User{})
      {:error, %Ecto.Changeset{}}

      ## if the platform API call fails for some reason
      iex> create_next_prediction(%Prediction{}, %Network{}, %User{})
      {:platform_error, reason}

  """
  def create_next_prediction(
        %Prediction{} = previous_prediction,
        %Network{} = network,
        %User{} = user
      ) do
    ## TODO it would be better if this function checked if the changeset were
    ## valid apart from the output before making the API call (to avoid making
    ## the API call if the other params were invalid)
    run_index = previous_prediction.run_index + 1
    model = Panic.Networks.model_at_index(network, run_index)
    input = previous_prediction.output
    output = Panic.Platforms.api_call(model, input, user)

    %{
      input: input,
      output: output,
      model: model,
      run_index: run_index,
      metadata: %{},
      network_id: network.id
    }
    |> create_prediction()
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
