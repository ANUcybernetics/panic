defmodule Panic.Models.ModelInfo do
  @enforce_keys [:id, :path, :name, :platform, :input_type, :output_type]
  defstruct [:id, :path, :name, :platform, :input_type, :output_type, :description, :homepage]

  @moduledoc """
  Struct containing all the model info:

  - `id`: string used as a unique identifier for the model
  - `path`: path to the hosted model (exactly how that translates into the final URL depends on the platform)
  - `version`: (optional, for replicate models) specify a specific version hash to use
  - `name`: human readable name for the model
  - `description`: brief description of the model (supports markdown)
  - `input_type`: input type (either `:text`, `:image` or `:audio`)
  - `output_type`: output type (either `:text`, `:image` or `:audio`)

  This information is stored in code (rather than in the database) because each
  model requires bespoke code to pull out the relevant return value (see the
  various versions of `create/3` in this module) and trying to keep that code in
  sync with this info in the database would be a nightmare.
  """

  def model_url(%__MODULE__{platform: Panic.Platforms.OpenAI}) do
    "https://platform.openai.com/docs/models/overview"
  end

  def model_url(%__MODULE__{platform: Panic.Models.Platforms.Replicate, path: path}) do
    "https://replicate.com/#{path}"
  end
end
