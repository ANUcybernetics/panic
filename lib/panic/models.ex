defmodule Panic.Models do
  @moduledoc """
  The Models context.
  """

  import Ecto.Query, warn: false
  alias Panic.Repo

  alias Panic.Models.Run

  @doc """
  Returns the list of models.

  Each is a string of the form PLATFORM:USERNAME/MODEL

  The models don't live in the DB anywhere, and for now we'll just keep this
  list up-to-date by hand

  """
  def list_models do
    [
      "replicate:kuprel/min-dalle",
      "replicate:rmokady/clip_prefix_caption"
    ]
  end

  @doc """
  Map model name to input/output modalities

  ## Examples

      iex> model_io("replicate:kuprel/min-dalle")
      {[:text], [:image]}
  """
  def model_io("replicate:kuprel/min-dalle"), do: {[:text], [:image]}
  def model_io("replicate:rmokady/clip_prefix_caption"), do: {[:image], [:text]}

  @doc """
  Returns the list of runs.

  ## Examples

      iex> list_runs()
      [%Run{}, ...]

  """
  def list_runs do
    Repo.all(Run)
  end

  @doc """
  Gets a single run.

  Raises `Ecto.NoResultsError` if the Run does not exist.

  ## Examples

      iex> get_run!(123)
      %Run{}

      iex> get_run!(456)
      ** (Ecto.NoResultsError)

  """
  def get_run!(id), do: Repo.get!(Run, id)

  @doc """
  Creates a run.

  ## Examples

      iex> create_run(%{field: value})
      {:ok, %Run{}}

      iex> create_run(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_run(attrs \\ %{}) do
    %Run{}
    |> Run.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a run.

  ## Examples

      iex> update_run(run, %{field: new_value})
      {:ok, %Run{}}

      iex> update_run(run, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_run(%Run{} = run, attrs) do
    run
    |> Run.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a run.

  ## Examples

      iex> delete_run(run)
      {:ok, %Run{}}

      iex> delete_run(run)
      {:error, %Ecto.Changeset{}}

  """
  def delete_run(%Run{} = run) do
    Repo.delete(run)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking run changes.

  ## Examples

      iex> change_run(run)
      %Ecto.Changeset{data: %Run{}}

  """
  def change_run(%Run{} = run, attrs \\ %{}) do
    Run.changeset(run, attrs)
  end
end
