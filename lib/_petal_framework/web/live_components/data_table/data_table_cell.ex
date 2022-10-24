defmodule PetalFramework.LiveComponents.DataTable.Cell do
  @moduledoc """
  Dependencies:
    {:timex, "~> 3.7"},
    {:currency_formatter, "~> 0.4"},
    {:petal_components, "~> 0.17"},
  """
  use Phoenix.Component
  import PetalComponents.Button

  def render(%{column: %{renderer: :checkbox}} = assigns) do
    ~H"""
    <%= if get_value(@item, @column) do %>
      <input type="checkbox" checked disabled />
    <% else %>
      <input type="checkbox" disabled />
    <% end %>
    """
  end

  def render(%{column: %{renderer: :date}} = assigns) do
    ~H"""
    <%= Timex.format!(get_value(@item, @column), @column[:date_format] || "{ISOdate}") %>
    """
  end

  def render(%{column: %{renderer: :datetime}} = assigns) do
    ~H"""
    <%= Timex.format!(get_value(@item, @column), @column[:date_format] || "{kitchen} {ISOdate}") %>
    """
  end

  def render(%{column: %{renderer: :money}} = assigns) do
    ~H"""
    <%= CurrencyFormatter.format(get_value(@item, @column), @column[:currency] || "USD") %>
    """
  end

  def render(%{column: %{renderer: :action_buttons}} = assigns) do
    ~H"""
    <%= for button <- @column.buttons.(@item) do %>
      <.button {button} />
    <% end %>
    """
  end

  # Plain text
  def render(assigns) do
    ~H"""
    <%= get_value(@item, @column) %>
    """
  end

  defp get_value(item, column) do
    cond do
      is_function(column[:renderer]) -> column.renderer.(item)
      !!column[:field] -> Map.get(item, column.field)
      true -> nil
    end
  end
end
