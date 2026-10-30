defmodule Panic.Accounts.Changes.IgnoreBlankArguments do
  @moduledoc """
  Drops the given arguments when they're nil or empty, so a blank form field
  leaves the stored value as it is.

  AshCloak turns each cloaked attribute into an argument of the same name, so
  this is how a blank key in `PlatformCredentials` keeps the encrypted one.
  """
  use Ash.Resource.Change

  @impl true
  def init(opts) do
    if is_list(opts[:arguments]), do: {:ok, opts}, else: {:error, "arguments must be a list"}
  end

  @impl true
  def change(changeset, opts, _context) do
    Enum.reduce(opts[:arguments], changeset, fn name, changeset ->
      case Ash.Changeset.fetch_argument(changeset, name) do
        {:ok, blank} when blank in [nil, ""] -> Ash.Changeset.delete_argument(changeset, name)
        _ -> changeset
      end
    end)
  end
end
