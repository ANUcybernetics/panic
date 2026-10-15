defmodule Panic.Accounts.ActorPersister do
  @moduledoc """
  Stores the actor of an Oban job (trigger or signal listener) as a user id,
  so jobs run as the network owner they were enqueued for.
  """
  use AshOban.ActorPersister

  alias Panic.Accounts.User

  @impl true
  def store(%User{id: id}), do: %{"type" => "user", "id" => id}

  @impl true
  def lookup(%{"type" => "user", "id" => id}), do: Ash.get(User, id, authorize?: false)
  def lookup(nil), do: {:ok, nil}
end
