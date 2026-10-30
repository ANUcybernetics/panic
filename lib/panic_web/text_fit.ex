defmodule PanicWeb.TextFit do
  @moduledoc """
  Sizes a text output to fill a 16:9 cell on its own (a single screen), where
  it needn't match any other card. A grid's cards share one size instead (see
  `.text-output` in `assets/css/app.css`).

  This is an estimate, for the first paint: the `.FitText` hook in
  `PanicWeb.PanicComponents.invocation_slot/1` then measures the text and
  settles on the largest size that fits, since how well text fills its box
  depends on where its lines break.

  The text box is the cell less 4% padding (of the cell's width) all round
  and `reserve`, the share of the cell's height kept clear at the bottom for
  whatever sits over it there (a caption, the QR code). A monospace character
  is 0.6em wide and a line 1.35em tall, so text of `n` characters fills a box
  `ratio` (height over width) at about √(ratio / (0.81 n)) of its width;
  `@wrap` allows for the end of each line that a word doesn't fit.
  """

  @padding 0.04
  @cell_ratio 9 / 16
  @wrap 0.85
  @max_cqw 12.0
  @min_cqw 1.5

  @doc """
  The font size, in cqw of the text box, that fills the box with `text`.

      iex> PanicWeb.TextFit.font_cqw("A mercenary delivers a flaming decoy to a triad leader in this surrealist cyberpunk action-comedy.", 0.0)
      6.91
      iex> PanicWeb.TextFit.font_cqw("hi", 0.0)
      12.0
  """
  def font_cqw(text, reserve) do
    width = 1 - 2 * @padding
    height = (1 - reserve) * @cell_ratio - 2 * @padding
    chars = max(String.length(text), 1)

    (100 * @wrap * :math.sqrt(height / width / (0.6 * 1.35 * chars)))
    |> max(@min_cqw)
    |> min(@max_cqw)
    |> Float.round(2)
  end

  @doc """
  The bottom padding, as CSS, that keeps `reserve` of the cell's height clear.

      iex> PanicWeb.TextFit.bottom_padding(0.12)
      "calc(4% + 6.75%)"
  """
  def bottom_padding(reserve) do
    "calc(#{round(@padding * 100)}% + #{Float.round(reserve * @cell_ratio * 100, 2)}%)"
  end
end
