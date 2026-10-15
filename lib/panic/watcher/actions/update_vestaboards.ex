defmodule Panic.Watcher.Actions.UpdateVestaboards do
  @moduledoc """
  Sends text to the Vestaboard watchers of a network's installations when a
  run starts (the prompt, to boards with `initial_prompt`) or an invocation
  completes (its output, to boards whose offset it lands on). See
  `Panic.Watcher.Vestaboards` for the rules.

  Vestaboard errors, and boards with no key in
  `Panic.Accounts.PlatformCredentials`, are logged and otherwise ignored:
  retrying would put stale text on a board after newer text.
  """
  use Ash.Resource.Actions.Implementation

  alias Panic.Accounts.PlatformCredentials
  alias Panic.Engine.Signals.InvocationCompleted
  alias Panic.Engine.Signals.RunStarted
  alias Panic.Platforms.Vestaboard
  alias Panic.Watcher.Installation
  alias Panic.Watcher.Vestaboards

  require Ash.Query
  require Logger

  @impl true
  def run(input, _opts, _context) do
    signal = input.arguments.signal

    signal.network_id
    |> vestaboard_watchers()
    |> Enum.flat_map(&messages(&1, signal))
    |> Enum.each(fn {board, text} ->
      case PlatformCredentials.vestaboard_token(board) do
        nil -> Logger.warning("Vestaboard #{board}: no key set, skipping")
        token -> Vestaboard.send_text(text, token, Atom.to_string(board))
      end
    end)

    :ok
  end

  defp vestaboard_watchers(network_id) do
    Installation
    |> Ash.Query.filter(network_id == ^network_id)
    |> Ash.read!(authorize?: false)
    |> Enum.flat_map(& &1.watchers)
    |> Vestaboards.vestaboard_watchers()
  end

  defp messages(watcher, %RunStarted{input: prompt}) do
    if watcher.initial_prompt, do: [{watcher.vestaboard_name, prompt}], else: []
  end

  defp messages(watcher, %InvocationCompleted{sequence_number: seq, output: output}) do
    if Vestaboards.shows_output?(watcher, seq), do: [{watcher.vestaboard_name, output}], else: []
  end
end
