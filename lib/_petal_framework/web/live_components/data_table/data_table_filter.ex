defmodule PetalFramework.LiveComponents.DataTable.Filter do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :field, :string
    field :op, :string
    field :value, :string
  end

  def changeset(zone, attrs) do
    zone
    |> cast(attrs, [
      :field,
      :op,
      :value
    ])
  end
end
