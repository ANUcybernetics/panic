defmodule Panic.Platforms.Model do
  defstruct [:id, :path, :name, :description, :input, :output, :platform]

  @moduledoc """
  Struct containing all the model info:

  - `id`: string used as a unique identifier for the model
  - `path`: path to the hosted model (exactly how that translates into the final URL depends on the platform)
  - `version`: (optional, for replicate models) specify a specific version hash to use
  - `name`: human readable name for the model
  - `description`: brief description of the model (supports markdown)
  - `input`: input type (either `:text`, `:image` or `:audio`)
  - `output`: output type (either `:text`, `:image` or `:audio`)

  This information is stored in code (rather than in the database) because each
  model requires bespoke code to pull out the relevant return value (see the
  various versions of `create/3` in this module) and trying to keep that code in
  sync with this info in the database would be a nightmare.
  """
end
