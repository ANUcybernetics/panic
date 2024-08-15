defmodule Panic.Workers.Invoker do
  use Oban.Worker, queue: :default

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => _id}}) do
    :ok
  end
end
