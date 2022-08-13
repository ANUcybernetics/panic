defmodule Panic.Models.Run do
  use Ecto.Schema
  import Ecto.Changeset
  alias Panic.Models

  schema "runs" do
    field :model, :string
    field :input, :string
    field :output, :string
    field :metadata, :map
    belongs_to :first_run, Models.Run

    timestamps()
  end

  @doc false
  def changeset(run, attrs) do
    run
    |> cast(attrs, [:model, :input, :output, :metadata, :first_run_id])
    |> validate_required([:model, :input, :first_run_id])
    |> validate_inclusion(:model, Models.list_models())
  end
end
