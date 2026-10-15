defmodule Panic.Watcher.Vestaboards do
  @moduledoc """
  Which text each Vestaboard watcher shows, as pure functions over watcher
  configs.

  A board shows the output of every invocation whose sequence number lands on
  its offset (`rem(sequence_number, stride) == offset`), the same rule single
  screen displays use. A board with `initial_prompt: true` also shows the
  prompt when a run starts.
  """

  alias Panic.Watcher.Installation.Config

  @doc """
  The vestaboard watchers among `watchers`.
  """
  def vestaboard_watchers(watchers), do: Enum.filter(watchers, &match?(%{type: :vestaboard}, &1))

  @doc """
  Whether any of `watchers` shows the initial prompt.

      iex> alias Panic.Watcher.Installation.Config
      iex> Panic.Watcher.Vestaboards.shows_initial_prompt?([%Config{type: :vestaboard, initial_prompt: true}])
      true
      iex> Panic.Watcher.Vestaboards.shows_initial_prompt?([%Config{type: :single, initial_prompt: false}])
      false
  """
  def shows_initial_prompt?(watchers) do
    watchers |> vestaboard_watchers() |> Enum.any?(& &1.initial_prompt)
  end

  @doc """
  Whether `watcher` shows the output of the invocation at `sequence_number`.

      iex> alias Panic.Watcher.Installation.Config
      iex> board = %Config{type: :vestaboard, stride: 4, offset: 1}
      iex> Panic.Watcher.Vestaboards.shows_output?(board, 5)
      true
      iex> Panic.Watcher.Vestaboards.shows_output?(board, 6)
      false
  """
  def shows_output?(%Config{type: :vestaboard, stride: stride, offset: offset}, sequence_number) do
    rem(sequence_number, stride) == offset
  end

  def shows_output?(_watcher, _sequence_number), do: false

  @doc """
  Whether any of `watchers` shows the output at `sequence_number`.
  """
  def any_shows_output?(watchers, sequence_number) do
    Enum.any?(watchers, &shows_output?(&1, sequence_number))
  end
end
