defmodule PanicWeb.RunFormatTest do
  use ExUnit.Case, async: true

  alias PanicWeb.RunFormat

  doctest RunFormat

  test "compares energy with an everyday use that reads naturally at its size" do
    assert RunFormat.everyday(0.0) == nil
    assert RunFormat.everyday(0.05) == "a few seconds of an LED bulb"
    assert RunFormat.everyday(2.0) == "12 minutes of an LED bulb"
    assert RunFormat.everyday(16.0) == "a phone charge"
    assert RunFormat.everyday(45.0) == "3 phone charges"
    assert RunFormat.everyday(1200.0) == "12 kettles boiled"
  end

  test "formats energy in sensible units" do
    assert RunFormat.energy(0.0) == "0.0 Wh"
    assert RunFormat.energy(5.8) == "5.8 Wh"
    assert RunFormat.energy(38.4) == "38 Wh"
    assert RunFormat.energy(2345.0) == "2.3 kWh"
  end

  test "formats cost, flagging amounts under a cent" do
    assert RunFormat.cost(0.0) == "US$0.00"
    assert RunFormat.cost(0.004) == "< US$0.01"
    assert RunFormat.cost(1.234) == "US$1.23"
  end

  test "formats a run's elapsed time to the minute" do
    start = ~U[2026-10-29 10:00:00Z]
    assert RunFormat.elapsed(start, ~U[2026-10-29 10:00:40Z]) == "under a minute"
    assert RunFormat.elapsed(start, ~U[2026-10-29 10:23:10Z]) == "23m"
    assert RunFormat.elapsed(start, ~U[2026-10-29 12:05:00Z]) == "2h 05m"
  end
end
