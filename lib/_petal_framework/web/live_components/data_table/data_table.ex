defmodule PetalFramework.LiveComponents.DataTable do
  @moduledoc """
  Render your data with ease. Uses Flop under the hood: https://github.com/woylie/flop

  ## Example

      <.live_component
        id="users-table"
        module={DataTable}
        url={@url}
        ecto_query={User}
        default_limit={20}
        default_order={%{
          order_by: [:id, :inserted_at],
          order_directions: [:asc, :asc]
        }}
        default_pagination_type={:page}
        page_size_options={[10, 20, 50]}
      >
        <:if_empty>No users found</:if_empty>
        <:col field={:id} type={:integer} filterable={[:==]} class="w-36" />
        <:col field={:name} sortable />
        <:col label="Actions" let={user}>
          <.button>Edit <%= user.name %></.button>
        </:col>
      </.live_component>

  ## Column definitions
  ### Sortable
      %{label: "ID", field: :id, sortable: true},

  ### Filterable
  You can filter your columns by using the `filterable` property.
        %{label: "Name", field: :name, filterable: [:ilike]},

  All available ops are:
    :==	"Salicaceae"	WHERE column = 'Salicaceae'
    :!=	"Salicaceae"	WHERE column != 'Salicaceae'
    :=~	"cyth"	WHERE column ILIKE '%cyth%'
    :empty	true	WHERE (column IS NULL) = true
    :empty	false	WHERE (column IS NULL) = false
    :not_empty	true	WHERE (column IS NOT NULL) = true
    :not_empty	false	WHERE (column IS NOT NULL) = false
    :<=	10	WHERE column <= 10
    :<	10	WHERE column < 10
    :>=	10	WHERE column >= 10
    :>	10	WHERE column > 10
    :in	["pear", "plum"]	WHERE column = ANY('pear', 'plum')
    :contains	"pear"	WHERE 'pear' = ANY(column)
    :like	"cyth"	WHERE column LIKE '%cyth%'
    :like_and	"Rubi Rosa"	WHERE column LIKE '%Rubi%' AND column LIKE '%Rosa%'
    :like_or	"Rubi Rosa"	WHERE column LIKE '%Rubi%' OR column LIKE '%Rosa%'
    :ilike	"cyth"	WHERE column ILIKE '%cyth%'
    :ilike_and	"Rubi Rosa"	WHERE column ILIKE '%Rubi%' AND column ILIKE '%Rosa%'
    :ilike_or	"Rubi Rosa"	WHERE column ILIKE '%Rubi%' OR column ILIKE '%Rosa%'

  ### Renderer
  Type is the type of cell that will be rendered.
          <:col field={:name} sortable renderer={:plaintext} />
          <:col field={:inserted_at} renderer={:date} date_format="{YYYY} />

  Renderers:

    :plaintext (for strings)
    :checkbox (for booleans)
    :date paired with optional param date_format: "{YYYY}" - s<% https://hexdocs.pm/timex/Timex.Format.DateTime.Formatters.Default.html %>
    :datetime paired with optional param date_format: "{YYYY}"
    :money paired with optional currency: "USD" (for money)

  ## Compound & join fields

  For these you will need to use https://hexdocs.pm/flop/Flop.Schema.html.

  Follow the instructions on setting up the `@derive` bit in your schema file.
  Then pass the schema into the live_component call:

      <.live_component
        ...
        for={User}
      >

  For join fields, make sure your `ecto_query` has a join in it. You have to name the join field too. Eg:

      # In your model
      @derive {
        Flop.Schema,
        filterable: [:field_from_joined_table],
        sortable: [:field_from_joined_table],
        join_fields: [field_from_joined_table: {:some_other_table, :field_name}]
      }

      # The ecto_query you pass to live_component:
      from(m in __MODULE__,
        join: u in assoc(m, :some_other_table),
        as: :some_other_table)

      # Now you can do a col with that field
      <:col field={:field_from_joined_table} let={something}>
        <%= something.some_other_table.field_name %>
      </:col>

  ### TODO
  - Can order_by joined table fields (e.g. customer.user.name)
  - Can filter by a select list of values ... eg Status: ["Active", "Inactive"]
  """
  use Phoenix.LiveComponent
  import PetalComponents.{Pagination, Table}
  alias PetalFramework.LiveComponents.DataTable.{Cell, Header, FilterSet, Filter}

  @defaults [
    default_limit: 20,
    default_pagination_type: :page,
    page_size_options: [10, 20, 50]
  ]

  @impl true
  def update(assigns, socket) do
    sortable =
      assigns.col
      |> Enum.filter(& &1[:sortable])
      |> Enum.map(& &1.field)

    filterable =
      assigns.col
      |> Enum.filter(& &1[:filterable])
      |> Enum.map(& &1.field)

    # We use inserted_at as the secondary order_by (in case the primary has all the same values)
    sortable = [:inserted_at | sortable]

    options =
      assigns
      |> Map.take([:default_limit, :default_order, :default_pagination_type, :for, :join_fields])
      |> Map.put_new(:default_limit, assigns[:default_page_size])
      |> Enum.map(& &1)
      |> Keyword.filter(fn {_k, v} -> v end)
      |> Keyword.merge(sortable: sortable, filterable: filterable)

    flop_opts = Keyword.merge(@defaults, options)
    uri = URI.parse(assigns.url)
    params = get_params_from_uri(uri)
    page_sizes = assigns[:page_size_options] || Keyword.get(@defaults, :page_size_options)

    default_assigns = [
      col: assigns[:col] || [],
      filter_changeset: FilterSet.changeset(%FilterSet{}),
      uri: uri,
      meta: nil,
      items: [],
      page_sizes: page_sizes,
      if_empty: assigns[:if_empty]
    ]

    case Flop.validate_and_run(assigns.ecto_query, params, flop_opts) do
      {:ok, {items, meta}} ->
        filter_changeset = build_filter_changeset(assigns.col, meta.flop)

        {:ok,
         assign(
           socket,
           Keyword.merge(default_assigns,
             filter_changeset: filter_changeset,
             meta: meta,
             items: items
           )
         )}

      {:error, meta} ->
        # Some error with the params. Ensure meta gets passed down and the error will show
        {:ok, assign(socket, Keyword.merge(default_assigns, meta: meta))}
    end
  end

  @impl true
  def render(%{meta: %{errors: []}} = assigns) do
    ~H"""
    <div>
      <.form
        :let={filter_form}
        id="data-table-filter-form"
        for={@filter_changeset}
        as={:filters}
        phx-change="update_filters"
        phx-submit="update_filters"
        phx-target={@myself}
      >
        <.table class="overflow-visible">
          <thead>
            <.tr>
              <%= for col <- @col do %>
                <Header.render
                  column={col}
                  meta={@meta}
                  filter_form={filter_form}
                  no_results?={@items == []}
                />
              <% end %>
            </.tr>
          </thead>
          <tbody>
            <%= if @items == [] do %>
              <.tr>
                <.td colspan={length(@col)}>
                  <%= if @if_empty, do: render_slot(@if_empty), else: "No results" %>
                </.td>
              </.tr>
            <% end %>

            <%= for item <- @items do %>
              <.tr>
                <%= for col <- @col do %>
                  <.td>
                    <%= if col[:inner_block] do %>
                      <%= render_slot(col, item) %>
                    <% else %>
                      <Cell.render column={col} item={item} />
                    <% end %>
                  </.td>
                <% end %>
              </.tr>
            <% end %>
          </tbody>
        </.table>
      </.form>

      <%= if @items != [] do %>
        <div class="flex items-center justify-between mt-5">
          <div class="text-sm text-gray-600 dark:text-gray-400">
            <div class="">
              Showing <%= get_first_item_index(@meta) %>-<%= get_last_item_index(@meta) %> of <%= @meta.total_count %> rows
            </div>
            <div class="flex gap-2">
              <div>Rows per page:</div>

              <%= for page_size <- @page_sizes do %>
                <%= if @meta.page_size == page_size do %>
                  <div class="font-semibold"><%= page_size %></div>
                <% else %>
                  <.link
                    patch={build_url_query(Map.put(@meta.flop, :page_size, page_size))}
                    class="block text-blue-500 dark:text-blue-400"
                  >
                    <%= page_size %>
                  </.link>
                <% end %>
              <% end %>
            </div>
          </div>

          <%= if @meta.total_pages > 1 do %>
            <.pagination
              link_type="live_patch"
              class="my-5"
              path={
                build_url_query(Map.put(@meta.flop, :page, ":page"))
                |> String.replace("%3Apage", ":page")
              }
              current_page={@meta.current_page}
              total_pages={@meta.total_pages}
            />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def render(%{meta: %{errors: errors}} = assigns) when is_list(errors) do
    ~H"""
    <div>
      <%= @meta.errors |> inspect() %>
      <%= if @uri.query do %>
        <.link href={@uri.path} class="underline">Reset</.link>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("update_filters", %{"filters" => filters}, socket) do
    changeset = FilterSet.changeset(%FilterSet{}, filters)

    case FilterSet.validate(changeset) do
      {:ok, _filter_set} ->
        query =
          to_query(socket.assigns.meta.flop)
          |> Keyword.put(:filters, filters["filters"])
          |> Keyword.put(:page, "1")

        to = socket.assigns.uri.path <> "?" <> Plug.Conn.Query.encode(query)
        {:noreply, push_patch(socket, to: to, replace: true)}

      {:error, changeset} ->
        {:noreply, assign(socket, filter_changeset: changeset)}
    end
  end

  defp get_first_item_index(meta) do
    if meta.current_page == 1 do
      1
    else
      (meta.current_page - 1) * meta.page_size + 1
    end
  end

  def get_last_item_index(meta) do
    if meta.current_page == meta.total_pages do
      meta.total_count
    else
      meta.current_page * meta.page_size
    end
  end

  def build_url_query(flop) do
    "?" <> (flop |> to_query |> Plug.Conn.Query.encode())
  end

  def to_query(%Flop{filters: filters} = flop, opts \\ []) do
    filter_map =
      filters
      |> Stream.with_index()
      |> Enum.into(%{}, fn {filter, index} ->
        {index, Map.from_struct(filter)}
      end)

    default_limit = Flop.get_option(:default_limit, opts)
    default_order = Flop.get_option(:default_order, opts)

    []
    |> maybe_put(:offset, flop.offset, 0)
    |> maybe_put(:page, flop.page, 1)
    |> maybe_put(:after, flop.after)
    |> maybe_put(:before, flop.before)
    |> maybe_put(:page_size, flop.page_size, default_limit)
    |> maybe_put(:limit, flop.limit, default_limit)
    |> maybe_put(:first, flop.first, default_limit)
    |> maybe_put(:last, flop.last, default_limit)
    |> maybe_put_order_params(flop, default_order)
    |> maybe_put(:filters, filter_map)
  end

  @doc """
  Puts a `value` under `key` only if the value is not `nil`, `[]` or `%{}`.

  If a `:default` value is passed, it only puts the value into the list if the
  value does not match the default value.

      iex> maybe_put([], :a, "b")
      [a: "b"]

      iex> maybe_put([], :a, nil)
      []

      iex> maybe_put([], :a, [])
      []

      iex> maybe_put([], :a, %{})
      []

      iex> maybe_put([], :a, "a", "a")
      []

      iex> maybe_put([], :a, "a", "b")
      [a: "a"]
  """
  @spec maybe_put(keyword, atom, any, any) :: keyword
  def maybe_put(params, key, value, default \\ nil)
  def maybe_put(keywords, _, nil, _), do: keywords
  def maybe_put(keywords, _, [], _), do: keywords
  def maybe_put(keywords, _, map, _) when map == %{}, do: keywords
  def maybe_put(keywords, _, val, val), do: keywords
  def maybe_put(keywords, key, value, _), do: Keyword.put(keywords, key, value)

  @doc """
  Puts the order params of a into a keyword list only if they don't match the
  defaults passed as the last argument.
  """
  @spec maybe_put_order_params(keyword, Flop.t() | map, map) :: keyword
  def maybe_put_order_params(
        params,
        %{order_by: order_by, order_directions: order_directions},
        %{order_by: order_by, order_directions: order_directions}
      ),
      do: params

  def maybe_put_order_params(
        params,
        %{order_by: order_by, order_directions: order_directions},
        _
      ) do
    params
    |> maybe_put(:order_by, order_by)
    |> maybe_put(:order_directions, order_directions)
  end

  defp build_filter_changeset(columns, flop) do
    filters =
      columns
      |> Enum.reduce([], fn col, acc ->
        if col[:filterable] do
          default_op = List.first(col.filterable)
          flop_filter = Enum.find(flop.filters, &(&1.field == col.field))

          filter = %Filter{
            field: col.field,
            op: (flop_filter && flop_filter.op) || default_op,
            value: (flop_filter && flop_filter.value) || nil
          }

          [filter | acc]
        else
          acc
        end
      end)

    filter_set = %FilterSet{filters: filters}
    FilterSet.changeset(filter_set)
  end

  def get_params_from_uri(uri), do: Plug.Conn.Query.decode(uri.query || "")
end
