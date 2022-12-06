defmodule Panic.Networks.Analytics do

  import Ecto.Query, warn: false
  alias Panic.Repo

  alias Panic.Models.Run
  alias Panic.Networks.Network


  def time_to_word(%Network{id: _id}, ""), do: {0, 0, 0}

  def time_to_word(%Network{id: id}, word) do
    num_runs = Repo.aggregate((from r in Run, where: r.network_id == ^id), :count)

    word_like = "%" <> word <> "%"

    query = from r in Run, where: r.network_id == ^id, where: like(r.output, ^word_like), group_by: r.first_run_id, select: {r.first_run_id, min(r.cycle_index)}

    cycle_lengths = Repo.all(query)

    avg_tts =
      cycle_lengths
      |> Enum.map(fn {_first_run_id, cycle_length} -> cycle_length end)
      |> mean()

    {num_runs, Enum.count(cycle_lengths) / num_runs, avg_tts}
  end

  def average_cycle_length(%Network{id: id}) do
    query = from r in Run, where: r.network_id == ^id, select: count(), group_by: r.first_run_id

    query
    |> Repo.all()
    |> mean()
  end

  defp mean([]), do: 0
  defp mean(list), do: Enum.sum(list) / Enum.count(list)
end
