defmodule Panic.Models.Run do
  use Ecto.Schema
  import Ecto.Changeset
  # alias Panic.Models.Platforms.Replicate

  @models [
    "replicate:kuprel/min-dalle",
    "rmokady/clip_prefix_caption"
  ]

  schema "runs" do
    field :input, :string
    field :metadata, :map
    field :model, :string
    field :output, :string

    timestamps()
  end

  @doc false
  def changeset(run, attrs) do
    run
    |> cast(attrs, [:model, :input, :output, :metadata])
    |> validate_required([:model, :input])
    |> validate_inclusion(:model, @models)
  end

  def models, do: @models
end
