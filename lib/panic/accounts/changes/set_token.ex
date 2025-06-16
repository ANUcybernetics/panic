defmodule Panic.Accounts.Changes.SetToken do
  @moduledoc """
  A change module for setting API tokens on users.

  This change accepts a token name and token value as arguments and sets the
  corresponding attribute on the user resource.
  """

  use Ash.Resource.Change

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def change(changeset, _opts, _context) do
    if changeset.valid? do
      case {Ash.Changeset.fetch_argument(changeset, :token_name), Ash.Changeset.fetch_argument(changeset, :token_value)} do
        {{:ok, token_name}, {:ok, token_value}} ->
          Ash.Changeset.force_change_attribute(changeset, token_name, token_value)

        _ ->
          changeset
      end
    else
      changeset
    end
  end

  @impl true
  def atomic?, do: true

  @impl true
  def atomic(changeset, _opts, _context) do
    case {Ash.Changeset.fetch_argument(changeset, :token_name), Ash.Changeset.fetch_argument(changeset, :token_value)} do
      {{:ok, token_name}, {:ok, token_value}} ->
        {:atomic, %{token_name => token_value}}

      _ ->
        {:not_atomic, "Missing required arguments token_name or token_value"}
    end
  end
end
