defmodule Panic.Models do
  @moduledoc """
  The Models context.
  """

  import Ecto.Query, warn: false
  alias Panic.Repo

  alias Panic.Models.Run
  alias Panic.Networks.Network

  @doc """
  Returns the list of models.

  Each is a string of the form PLATFORM:USERNAME/MODEL

  The models don't live in the DB anywhere, and for now we'll just keep this
  list up-to-date by hand

  """
  def list_models do
    [
      "replicate:benswift/min-dalle",
      "replicate:laion-ai/ongo",
      "replicate:rmokady/clip_prefix_caption",
      "replicate:j-min/clip-caption-reward",
      "replicate:netease-gameai/spatchgan-selfie2anime",
      "replicate:annahung31/emopia",
      "replicate:afiaka87/tortoise-tts",
      "openai:text-davinci-002",
      "huggingface:facebook/fastspeech2-en-ljspeech",
      "huggingface:facebook/wav2vec2-base-960h"
    ]
  end

  @doc """
  Map model name to input/output modalities

  ## Examples

      iex> model_io("replicate:benswift/min-dalle")
      {:text, :image}
  """
  def model_io("replicate:benswift/min-dalle"), do: {:text, :image}
  def model_io("replicate:laion-ai/ongo"), do: {:text, :image}
  def model_io("replicate:rmokady/clip_prefix_caption"), do: {:image, :text}
  def model_io("replicate:j-min/clip-caption-reward"), do: {:image, :text}
  def model_io("replicate:netease-gameai/spatchgan-selfie2anime"), do: {:image, :image}
  def model_io("replicate:afiaka87/tortoise-tts"), do: {:text, :audio}
  def model_io("replicate:annahung31/emopia"), do: {:text, :audio}
  def model_io("openai:text-davinci-002"), do: {:text, :text}
  def model_io("huggingface:facebook/fastspeech2-en-ljspeech"), do: {:text, :audio}
  def model_io("huggingface:facebook/wav2vec2-base-960h"), do: {:audio, :text}

  def list_runs(%Network{id: network_id}) do
    Repo.all(from r in Run, where: r.network_id == ^network_id, order_by: [asc: r.id])
  end

  def list_runs(first_run_id) do
    Repo.all(from r in Run, where: r.first_run_id == ^first_run_id, order_by: [asc: r.id])
  end

  @doc """
  Returns the list of runs.

  ## Examples

  iex> list_runs()
  [%Run{}, ...]

  """

  def list_runs do
    Repo.all(from r in Run, order_by: [asc: r.id])
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

  def cycle_has_converged?(first_run_id) do
    case list_runs(first_run_id) do
      [] -> false
      runs -> runs |> Enum.reduce_while([],
        fn x, acc ->
          if x.output in acc, do: {:halt, []}, else: {:cont, [x.output | acc]}
        end)
        |> Enum.empty?
    end
  end
end
