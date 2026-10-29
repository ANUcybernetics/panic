defmodule Panic.Watcher.Vestaboards do
  @moduledoc """
  Which text each Vestaboard watcher shows, as pure functions over watcher
  configs, and whether a piece of text fits on a board (6 rows of 22
  columns, word-wrapped).

  A board shows the output of every invocation whose sequence number lands on
  its offset (`rem(sequence_number, stride) == offset`), the same rule single
  screen displays use. A board with `initial_prompt: true` also shows the
  prompt when a run starts.

  Each installation's `vestaboard_hold_seconds` is how long its boards take to
  settle: the invocation after one they display holds its output back that
  long (see `Panic.Engine.Schedule`).
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
  How long, in seconds, the invocation after `sequence_number` holds its
  output back: the longest `vestaboard_hold_seconds` among `installations`
  with a board showing that output, or nil when none does.

      iex> alias Panic.Watcher.Installation.Config
      iex> board = %Config{type: :vestaboard, stride: 2, offset: 1}
      iex> installations = [
      ...>   %{vestaboard_hold_seconds: 10, watchers: [board]},
      ...>   %{vestaboard_hold_seconds: 12, watchers: [%Config{type: :single, stride: 2, offset: 1}]}
      ...> ]
      iex> Panic.Watcher.Vestaboards.output_hold_seconds(installations, 1)
      10
      iex> Panic.Watcher.Vestaboards.output_hold_seconds(installations, 2)
      nil
  """
  def output_hold_seconds(installations, sequence_number) do
    max_hold(installations, fn watchers ->
      Enum.any?(watchers, &shows_output?(&1, sequence_number))
    end)
  end

  @doc """
  How long, in seconds, the first invocation of a run holds its output back
  so the initial prompt stays readable, or nil when no board shows it.

      iex> alias Panic.Watcher.Installation.Config
      iex> board = %Config{type: :vestaboard, initial_prompt: true}
      iex> Panic.Watcher.Vestaboards.initial_prompt_hold_seconds([%{vestaboard_hold_seconds: 8, watchers: [board]}])
      8
      iex> Panic.Watcher.Vestaboards.initial_prompt_hold_seconds([%{vestaboard_hold_seconds: 8, watchers: []}])
      nil
  """
  def initial_prompt_hold_seconds(installations) do
    max_hold(installations, &shows_initial_prompt?/1)
  end

  defp max_hold(installations, displays?) do
    installations
    |> Enum.filter(&displays?.(&1.watchers))
    |> Enum.map(& &1.vestaboard_hold_seconds)
    |> Enum.max(fn -> nil end)
  end

  @columns 22
  @rows 6

  @doc """
  `text` word-wrapped to the width of a board, breaking words longer than a
  line.

      iex> Panic.Watcher.Vestaboards.wrap("a tabby cat grooms by a roaring stone fireplace")
      ["a tabby cat grooms by", "a roaring stone", "fireplace"]
  """
  def wrap(text) do
    text
    |> String.split()
    |> Enum.flat_map(
      &(&1
        |> String.graphemes()
        |> Enum.chunk_every(@columns)
        |> Enum.map(fn g -> Enum.join(g) end))
    )
    |> Enum.reduce([], fn
      word, [] ->
        [word]

      word, [line | rest] ->
        if String.length(line) + 1 + String.length(word) <= @columns,
          do: ["#{line} #{word}" | rest],
          else: [word, line | rest]
    end)
    |> Enum.reverse()
  end

  @doc """
  Whether `text` fits on a board once word-wrapped.

      iex> Panic.Watcher.Vestaboards.fits?("a cat on a mat")
      true
      iex> Panic.Watcher.Vestaboards.fits?(String.duplicate("word ", 30))
      false
  """
  def fits?(text), do: length(wrap(text)) <= @rows

  @doc """
  `text` cut back a word at a time until it fits on a board.

      iex> Panic.Watcher.Vestaboards.trim_to_fit(String.duplicate("word ", 30))
      String.trim(String.duplicate("word ", 24))
  """
  def trim_to_fit(text) do
    text
    |> String.split()
    |> Stream.iterate(&Enum.drop(&1, -1))
    |> Enum.find(&fits?(Enum.join(&1, " ")))
    |> Enum.join(" ")
  end

  @doc """
  `text` on one line with typographic punctuation and accents swapped for
  characters a board can show, and anything else dropped.

      iex> Panic.Watcher.Vestaboards.sanitise("A café’s “neon” sign — glowing 🌙\\n")
      "A cafe's neon sign, glowing"
  """
  def sanitise(text) do
    text
    |> String.replace(["‘", "’"], "'")
    |> String.replace(["“", "”", "*"], "")
    |> String.replace(~r/\s*[—–]\s*/u, ", ")
    |> String.replace(~r/[‐‑]/u, "-")
    |> String.normalize(:nfd)
    |> String.replace(~r/[^A-Za-z0-9 !@#$()\-+&=;:'"%,.\/?\s]/u, "")
    |> String.split()
    |> Enum.join(" ")
  end
end
