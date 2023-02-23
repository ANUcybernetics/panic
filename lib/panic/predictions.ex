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
  Creates a prediction from a map of `attrs`.

  Unless you're creating a prediction from a "raw" map of attrs, it's probably
  easier to call one of the other `create_prediction` functions (which will hit
  the API for you, fix up the genesis block stuff, keep track of run index,
  etc.).

  ## Examples

      iex> create_prediction_from_attrs(%{field: value})
      {:ok, %Prediction{}}

      iex> create_prediction_from_attrs(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_prediction_from_attrs(attrs) do
    %Prediction{}
    |> Prediction.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, prediction} -> {:ok, Repo.preload(prediction, [:network])}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def genesis_changeset(%Network{} = network, attrs \\ %{}) do
    %{
      model: List.first(network.models),
      run_index: 0,
      metadata: %{},
      network_id: network.id
    }
    |> Map.merge(attrs)
    |> create_prediction_from_attrs()
  end

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

      iex> create_prediction("this is a text input prompt", %Network{}, tokens)
      {:ok, %Prediction{}}

      ## if any of the arguments are invalid
      iex> create_prediction(12345, %Network{}, tokens)
      {:error, %Ecto.Changeset{}}

      ## if the platform API call fails for some reason
      iex> create_prediction("valid text input", %Network{}, tokens)
      {:platform_error, reason}

  """
  def create_prediction(input, %Network{} = network, tokens) when is_binary(input) do
    {:error, changeset} = genesis_changeset(network, %{input: input})

    case changeset do
      # if the only error is the missing output, make the API call
      %{errors: [output: _]} ->
        {:ok, output} =
          Panic.Platforms.api_call(changeset.changes.model, changeset.changes.input, tokens)

        {:ok, %Prediction{id: id} = prediction} =
          create_prediction_from_attrs(changeset.changes |> Map.put(:output, output))

        ## it's a first run, so set :genesis_id to :id
        update_prediction(prediction, %{genesis_id: id})

      # otherwise just return the error changeset
      _ ->
        {:error, changeset}
    end
  end

  @doc """
  Async version of `create_prediction(input, %Network{}, tokens)` for creating a "genesis" prediction.

  `on_exit/1` is a function which will be called with the new prediction as the
  sole argument.

  Uses `Panic.Runs.TaskSupervisor` with `restart: transient`, so it'll keep
  re-trying until it exits cleanly.
  """
  def create_prediction_async(input, %Network{} = network, tokens, on_exit)
      when is_binary(input) do
    Task.Supervisor.start_child(
      Panic.Runs.TaskSupervisor,
      fn ->
        {:ok, next_prediction} = create_prediction(input, network, tokens)
        on_exit.(next_prediction)
      end,
      restart: :transient
    )
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

      iex> create_prediction(%Prediction{}, tokens)
      {:ok, %Prediction{}}

      ## if any of the arguments are invalid
      iex> create_prediction(nil, tokens)
      {:error, %Ecto.Changeset{}}

      ## if the platform API call fails for some reason
      iex> create_prediction(%Prediction{}, tokens)
      {:platform_error, reason}

  """
  def create_prediction(%Prediction{} = previous_prediction, tokens) do
    ## TODO it would be better if this function checked if the changeset were
    ## valid apart from the output before making the API call (to avoid making
    ## the API call if the other params were invalid)
    run_index = previous_prediction.run_index + 1
    network = previous_prediction.network
    model = Enum.at(network.models, Integer.mod(run_index, Enum.count(network.models)))
    input = previous_prediction.output

    {:ok, output} = Panic.Platforms.api_call(model, input, tokens)

    %{
      input: input,
      output: output,
      model: model,
      run_index: run_index,
      metadata: %{},
      network_id: network.id,
      genesis_id: previous_prediction.genesis_id
    }
    |> create_prediction_from_attrs()
  end

  @doc """
  Async version of `create_prediction(%Prediction{}, tokens)` for creating a "next" prediction.

  `on_exit/1` is a function which will be called with the new prediction as the
  sole argument.

  Uses `Panic.Runs.TaskSupervisor` with `restart: transient`, so it'll keep
  re-trying until it exits cleanly.
  """
  def create_prediction_async(%Prediction{} = previous_prediction, tokens, on_exit) do
    Task.Supervisor.start_child(
      Panic.Runs.TaskSupervisor,
      fn ->
        {:ok, next_prediction} = create_prediction(previous_prediction, tokens)
        on_exit.(next_prediction)
      end,
      restart: :transient
    )
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
