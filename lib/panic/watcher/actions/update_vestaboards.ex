defmodule Panic.Watcher.Actions.UpdateVestaboards do
  @moduledoc """
  Sends text to the Vestaboard watchers of a network's installations when a
  run starts (the prompt, to boards with `initial_prompt`) or an invocation
  completes (its output, to boards whose offset it lands on). See
  `Panic.Watcher.Vestaboards` for the rules.

  Vestaboard errors are logged by the platform module and otherwise ignored:
  retrying would put stale text on a board after newer text.
  """
  use Ash.Resource.Actions.Implementation

  alias Panic.Engine.Signals.InvocationCompleted
  alias Panic.Engine.Signals.RunStarted
  alias Panic.Platforms.Vestaboard
  alias Panic.Watcher.Installation
  alias Panic.Watcher.Vestaboards

  require Ash.Query

  @impl true
  def run(input, _opts, context) do
    signal = input.arguments.signal

    signal.network_id
    |> vestaboard_watchers()
    |> Enum.flat_map(&messages(&1, signal))
    |> Enum.each(fn {board_name, text} ->
      token = Vestaboard.token_for_board!(board_name, context.actor)
      Vestaboard.send_text(text, token, board_name)
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
    if watcher.initial_prompt, do: [{board_name(watcher), prompt}], else: []
  end

  defp messages(watcher, %InvocationCompleted{sequence_number: seq, output: output}) do
    if Vestaboards.shows_output?(watcher, seq), do: [{board_name(watcher), output}], else: []
  end

  defp board_name(watcher), do: Atom.to_string(watcher.vestaboard_name)
end
