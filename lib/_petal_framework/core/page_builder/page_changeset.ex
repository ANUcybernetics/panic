defmodule Panic.PageChangeset do
  @moduledoc """
  Used in the PageBuilderLive form.
  """
  import Ecto.Changeset

  def build(params) do
    data = %{}

    types = %{
      type: :string,
      layout: :string,
      route_section: :string,
      route_path: :string,
      controller_function_name: :string,
      live_view_module_name: :string,
      page_title: :string
    }

    {data, types}
    |> cast(params, Map.keys(types))
    |> validate_required([
      :type,
      :layout,
      :route_section,
      :route_path,
      :page_title
    ])
  end

  def validate(changeset) do
    apply_action(changeset, :validate)
  end
end
