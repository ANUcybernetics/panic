defmodule PanicWeb.AdminUsersLive.UserFilterChangeset do
  import Ecto.Changeset

  def build(params \\ %{}) do
    data = %{
      text_search: "",
      is_suspended: false,
      is_deleted: false
    }

    types = %{
      text_search: :string,
      is_suspended: :boolean,
      is_deleted: :boolean
    }

    {data, types}
    |> cast(params, Map.keys(types))
  end

  def validate(changeset) do
    apply_action(changeset, :validate)
  end
end
