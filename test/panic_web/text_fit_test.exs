defmodule PanicWeb.TextFitTest do
  use ExUnit.Case, async: true

  alias PanicWeb.TextFit

  doctest TextFit

  test "longer text and a bigger reserve both make the text smaller" do
    short = String.duplicate("word ", 20)
    long = String.duplicate("word ", 100)

    assert TextFit.font_cqw(long, 0.0) < TextFit.font_cqw(short, 0.0)
    assert TextFit.font_cqw(short, 0.36) < TextFit.font_cqw(short, 0.0)
  end
end
