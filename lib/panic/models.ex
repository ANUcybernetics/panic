defmodule Panic.Models do
  @moduledoc """
  The Models context.
  """

  import Ecto.Query, warn: false
  alias Panic.Repo

  alias Panic.Models.Run
  alias Panic.Networks.Network
  alias Panic.Models.Platforms.{Replicate, OpenAI, HuggingFace}

  @doc """
  Returns the list of models.

  Each is a string of the form PLATFORM:USERNAME/MODEL

  The models don't live in the DB anywhere, and for now we'll just keep this
  list up-to-date by hand

  """
  def list_models do
    [
      "huggingface:facebook/fastspeech2-en-ljspeech",
      "huggingface:facebook/wav2vec2-base-960h",
      "openai:text-davinci-002",
      "replicate:charlesfrye/text-recognizer-gpu",
      "replicate:kuprel/min-dalle",
      "replicate:kyrick/prompt-parrot",
      "replicate:methexis-inc/img2prompt",
      "replicate:rmokady/clip_prefix_caption",
      "replicate:j-min/clip-caption-reward",
      "replicate:stability-ai/stable-diffusion"
    ]
  end

  @doc """
  Map model name to input/output modalities

  ## Examples

      iex> model_io("replicate:kuprel/min-dalle")
      {:text, :image}
  """
  def model_io("huggingface:facebook/fastspeech2-en-ljspeech"), do: {:text, :audio}
  def model_io("huggingface:facebook/wav2vec2-base-960h"), do: {:audio, :text}
  def model_io("openai:text-davinci-002"), do: {:text, :text}
  def model_io("replicate:charlesfrye/text-recognizer-gpu"), do: {:image, :text}
  def model_io("replicate:kuprel/min-dalle"), do: {:text, :image}
  def model_io("replicate:kyrick/prompt-parrot"), do: {:text, :text}
  def model_io("replicate:methexis-inc/img2prompt"), do: {:image, :text}
  def model_io("replicate:rmokady/clip_prefix_caption"), do: {:image, :text}
  def model_io("replicate:j-min/clip-caption-reward"), do: {:image, :text}
  def model_io("replicate:stability-ai/stable-diffusion"), do: {:text, :image}

  def list_runs(%Network{id: network_id}) do
    Repo.all(from r in Run, where: r.network_id == ^network_id, order_by: [asc: r.cycle_index])
  end

  def list_runs(first_run_id) do
    Repo.all(
      from r in Run, where: r.first_run_id == ^first_run_id, order_by: [asc: r.cycle_index]
    )
  end

  @doc """
  Returns the list of runs.

  ## Examples

  iex> list_runs()
  [%Run{}, ...]

  """
  def list_runs do
    Repo.all(from r in Run, order_by: [asc: r.cycle_index])
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
  Creates a first run.
  """
  def create_first_run(%Network{id: network_id, models: models}, attrs \\ %{}) do
    result =
      %Run{}
      |> Run.changeset(
        Map.merge(attrs, %{
          "network_id" => network_id,
          "model" => List.first(models),
          "cycle_index" => 0
        })
      )
      |> Repo.insert()

    case result do
      {:ok, run} -> update_run(run, %{first_run_id: run.id})
      {:error, changeset} -> {:error, changeset}
    end
  end

  def create_next_run(
        %Network{id: network_id, models: models},
        %Run{cycle_index: cycle_index, first_run_id: first_run_id, output: next_input} =
          _parent_run,
        attrs \\ %{}
      ) do
    next_model = Enum.at(models, Integer.mod(cycle_index + 1, Enum.count(models)))

    attrs =
      Map.merge(attrs, %{
        "network_id" => network_id,
        "model" => next_model,
        "input" => next_input,
        "cycle_index" => cycle_index + 1,
        "first_run_id" => first_run_id
      })

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

  @doc """
  "Dispatch" a model (async) by making a call to the relevant API

  This function returns the (updated) %Run{} struct immediately, and when the
  API call finishes it will broadcast the completed run via :run_completed on
  the PubSub
  """

  def dispatch_run(%Run{model: model, input: input, network_id: network_id} = run) do
    [platform, model_name] = String.split(model, ":")

    # this is the async part, will broadcast the :run_completed event when done
    Panic.BackgroundTask.run(fn ->
      output =
        case platform do
          "replicate" -> Replicate.create(model_name, input)
          "openai" -> OpenAI.create(model_name, input)
          "huggingface" -> HuggingFace.create(model_name, input)
        end

      {:ok, updated_run} = update_run(run, %{output: output})

      unless updated_run.cycle_index < 6 or updated_run.model == "replicate:rmokady/clip_prefix_caption" do
        ## after the first few, sleep so things don't get *too* quick
        Process.sleep(5_000)
      end

      Panic.Networks.broadcast(network_id, {:run_completed, %{updated_run | status: :succeeded}})
    end)
  end

  def cycle_has_converged?(%Run{first_run_id: id}) do
    case list_runs(id) do
      [] ->
        false

      runs ->
        runs
        |> Enum.reduce_while(
          [],
          fn x, acc ->
            if x.output in acc, do: {:halt, []}, else: {:cont, [x.output | acc]}
          end
        )
        |> Enum.empty?()
    end
  end

  def is_first_run?(%Run{cycle_index: idx}), do: idx == 0
  def same_cycle?(%Run{first_run_id: id1}, %Run{first_run_id: id2}), do: id1 == id2
end
