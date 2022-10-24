defmodule PetalFramework.LiveComponents.DataTable.Header do
  use Phoenix.Component
  import PetalComponents.{Table, Link, Form, Dropdown}
  alias PetalComponents.HeroiconsV1
  alias PetalFramework.LiveComponents.DataTable
  import Phoenix.HTML.Form

  def render(assigns) do
    index = order_index(assigns.meta.flop, assigns.column[:field])
    direction = order_direction(assigns.meta.flop.order_directions, index)

    assigns =
      assigns
      |> assign(:currently_ordered, index == 0)
      |> assign(:order_direction, direction)

    ~H"""
    <.th class={"align-top #{@column[:class] || ""}"}>
      <div>
        <%= if @column[:sortable] && !@no_results? do %>
          <.a
            class={
              "flex items-center gap-3 #{if @currently_ordered, do: "text-gray-900 dark:text-white font-semibold", else: "text-gray-500 dark:text-gray-400"}"
            }
            to={
              DataTable.build_url_query(
                Map.merge(@meta.flop, %{
                  order_by: [@column.field, @column[:order_by_backup] || :inserted_at],
                  order_directions:
                    cond do
                      @currently_ordered && @order_direction == :desc ->
                        [:asc, :desc]

                      @currently_ordered && @order_direction == :asc ->
                        [:desc, :desc]

                      true ->
                        [:asc, :desc]
                    end
                })
              )
            }
            link_type="live_patch"
          >
            <%= get_label(@column) %>
            <HeroiconsV1.Outline.render
              icon={
                if @currently_ordered && @order_direction == :desc,
                  do: :chevron_down,
                  else: :chevron_up
              }
              class="h-4"
            />
          </.a>
        <% else %>
          <%= get_label(@column) %>
        <% end %>
      </div>
      <%= if @column[:filterable] && !@no_results? do %>
        <%= for f2 <- inputs_for(@filter_form, :filters) do %>
          <%= if input_value(f2, :field) == @column.field do %>
            <%= hidden_inputs_for(f2) %>
            <%= hidden_input(f2, :field) %>

            <div class="flex items-center gap-2 mt-2">
              <%= case @column[:type] do %>
                <% :integer -> %>
                  <.number_input
                    form={f2}
                    field={:value}
                    phx-debounce="200"
                    placeholder={get_filter_placeholder(input_value(f2, :op))}
                    class="!text-xs !py-1"
                  />
                <% :boolean -> %>
                  <.select
                    form={f2}
                    field={:value}
                    options={[{"True", true}, {"False", false}]}
                    prompt="-"
                    class="!text-xs !py-1"
                    size="sm"
                  />
                <% _ -> %>
                  <.search_input
                    form={f2}
                    field={:value}
                    phx-debounce="200"
                    placeholder={get_filter_placeholder(input_value(f2, :op))}
                    class="!text-xs !py-1"
                  />
              <% end %>

              <%= if length(@column[:filterable]) > 1 do %>
                <.dropdown>
                  <:trigger_element>
                    <div class="inline-flex items-center justify-center w-full align-middle focus:outline-none">
                      <HeroiconsV1.Outline.filter class="w-4 h-4 text-gray-400 dark:text-gray-600" />
                      <HeroiconsV1.Solid.chevron_down class="w-4 h-4 ml-1 -mr-1 text-gray-400 dark:text-gray-100" />
                    </div>
                  </:trigger_element>
                  <div class="p-3 font-normal normal-case">
                    <.form_field
                      type="radio_group"
                      form={f2}
                      field={:op}
                      label="Operation"
                      options={@column.filterable |> Enum.map(&{get_filter_placeholder(&1), &1})}
                    />
                  </div>
                </.dropdown>
              <% else %>
                <%= hidden_input(f2, :op) %>
              <% end %>
            </div>
          <% end %>
        <% end %>
      <% end %>
    </.th>
    """
  end

  defp get_label(column) do
    case column[:label] do
      nil ->
        humanize(column.field)

      label ->
        label
    end
  end

  defp order_index(%Flop{order_by: nil}, _), do: nil

  defp order_index(%Flop{order_by: order_by}, field) do
    Enum.find_index(order_by, &(&1 == field))
  end

  defp order_direction(_, nil), do: nil
  defp order_direction(nil, _), do: :asc
  defp order_direction(directions, index), do: Enum.at(directions, index)

  defp get_filter_placeholder(op) do
    op_map()[op]
  end

  # List of op options
  def op_map do
    %{
      ==: "Equals",
      !=: "Not equal",
      =~: "Search (case insensitive)",
      empty: "Is empty",
      not_empty: "Not empty",
      <=: "Less than or equals",
      <: "Less than",
      >=: "Greater than or equals",
      >: "Greater than",
      in: "Search in",
      contains: "Contains",
      like: "Search (case sensitive)",
      like_and: "Search (case sensitive) (and)",
      like_or: "Search (case sensitive) (or)",
      ilike: "Search (case insensitive)",
      ilike_and: "Search (case insensitive) (and)",
      ilike_or: "Search (case insensitive) (or)"
    }
  end
end
