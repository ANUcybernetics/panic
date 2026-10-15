defmodule Panic.Engine.DoctestTest do
  use ExUnit.Case, async: true

  doctest Panic.Engine.Schedule
  doctest Panic.Watcher.Vestaboards
end
