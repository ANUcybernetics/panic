defmodule Panic.Models.Run do
  use Ecto.Schema
  import Ecto.Changeset
  # alias Panic.Models.Platforms.Replicate

  @models [
    "replicate:kuprel/min-dalle"
  ]

  schema "runs" do
    field :input, :string
    field :metadata, :map
    field :model_name, :string
    field :output, :string

    timestamps()
  end

  @doc false
  def changeset(run, attrs) do
    run
    |> cast(attrs, [:model_name, :input, :output, :metadata])
    |> validate_required([:model_name, :input])
    |> validate_inclusion(:model_name, @models)
  end

  def models, do: @models
end
