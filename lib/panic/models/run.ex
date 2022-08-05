defmodule Panic.Models.Run do
  use Ecto.Schema
  import Ecto.Changeset

  schema "runs" do
    field :input, :string
    field :metadata, :map
    field :model_name, :string
    field :output, :string
    field :platform, Ecto.Enum, values: [:replicate, :huggingface, :openai]

    timestamps()
  end

  @doc false
  def changeset(run, attrs) do
    run
    |> cast(attrs, [:platform, :model_name, :input, :output, :metadata])
    |> validate_required([:platform, :model_name, :input])
  end
end
