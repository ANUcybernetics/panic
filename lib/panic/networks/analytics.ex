defmodule Panic.Networks.Analytics do

  import Ecto.Query, warn: false
  alias Panic.Repo

  alias Panic.Models.Run
  alias Panic.Networks.Network

  def average_cycle_length(%Network{id: id}) do
    Repo.all(from r in Run, where: r.network_id == ^id, select: count(), group_by: r.first_run_id)
    |> mean()
  end

  defp mean(list), do: Enum.sum(list) / Enum.count(list)
end
