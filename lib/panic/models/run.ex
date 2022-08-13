defmodule Panic.Models.Run do
  use Ecto.Schema
  import Ecto.Changeset
  alias Panic.Models

  schema "runs" do
    field :model, :string
    field :input, :string
    field :output, :string
    field :metadata, :map
    field :first_run_id, :id

    timestamps()
  end

  @doc false
  def changeset(run, attrs) do
    run
    |> cast(attrs, [:model, :input, :output, :metadata])
    |> validate_required([:model, :input])
    |> validate_inclusion(:model, Models.list_models())
  end
end
