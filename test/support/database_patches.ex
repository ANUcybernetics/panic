defmodule PanicWeb.Helpers.DatabasePatches do
  @moduledoc """
  Convenience module for setting up database patches in test modules.

  ## Usage

      defmodule MyTest do
        use ExUnit.Case, async: false
        use PanicWeb.Helpers.DatabasePatches

        # Your tests here...
      end

  This is equivalent to adding:

      setup_all do
        PanicWeb.Helpers.setup_database_patches()
        :ok
      end
  """

  defmacro __using__(_opts) do
    quote do
      setup_all do
        PanicWeb.Helpers.setup_database_patches()
        :ok
      end
    end
  end
end