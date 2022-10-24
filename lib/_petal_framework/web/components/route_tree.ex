defmodule PetalFramework.Components.RouteTree do
  use Phoenix.Component
  use PetalComponents
  alias Phoenix.LiveView.JS

  @moduledoc """
  Show's a list of your apps routes. Can copy the helper function for any route.

  Usage:
      <.route_tree router={YourAppWeb.Router} />
  """

  attr :router, :any, doc: "Your application router module"

  def route_tree(assigns) do
    all_routes =
      Phoenix.Router.routes(assigns.router)
      |> Enum.map(fn route -> Map.put(route, :path_list, split_path(route.path)) end)

    assigns = assign(assigns, all_routes: all_routes, sections: get_sections(all_routes))

    ~H"""
    <div class="flex flex-col gap-1 ml-[60px]">
      <%= for key <- @sections do %>
        <div class="mt-3 font-bold"><%= Phoenix.HTML.Form.humanize(key) %></div>
        <%= for route <- get_routes_by_key(key, @all_routes, @sections) do %>
          <.route route={route} />
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :route, :map

  def route(assigns) do
    ~H"""
    <div
      class="relative flex items-center justify-between hover:bg-slate-50 dark:hover:bg-slate-800"
      id={route_id(@route)}
      phx-hook="TippyHook"
      data-tippy-content={"Click to copy " <> get_route_helper(@route)}
      phx-click={
        JS.toggle(
          to: "##{route_id(@route)}_children",
          in: {"ease-out duration-300", "opacity-0", "opacity-100"}
        )
        |> toggle_class("##{route_id(@route)}_chevron", "-rotate-90")
      }
    >
      <div
        class="flex items-center w-full gap-2 cursor-pointer"
        id={route_id(@route) <> "_copy_button"}
        phx-hook="ClipboardHook"
        data-content={get_route_helper(@route)}
      >
        <div class="absolute left-[-60px] w-[46px] flex justify-end">
          <.badge color={get_verb_color(get_verb(@route))} size="sm" label={get_verb(@route)} />
        </div>
        <div class="text-sm font-semibold"><%= @route.path %></div>
        <div class="">
          <HeroiconsV1.Solid.arrow_narrow_right class="h-4" />
        </div>
        <div class="text-sm">
          <%= get_module(@route) %>
        </div>
        <div class="flex gap-3 text-sm text-gray-500 dark:text-gray-400">
          <%= get_action(@route) %>
          <div class="before-copied"></div>
          <div class="hidden text-green-600 after-copied dark:text-green-300">Copied!</div>
        </div>

        <%= if @route[:children] do %>
          <HeroiconsV1.Solid.chevron_down
            id={route_id(@route) <> "_chevron"}
            class="flex-shrink-0 w-4 h-4 ml-3 text-gray-400 duration-300 -rotate-90 fill-current dark:group-hover:text-gray-300 group-hover:text-gray-500"
          />
        <% end %>
      </div>
    </div>

    <%= if @route[:children] do %>
      <div
        id={route_id(@route) <> "_children"}
        class="flex flex-col gap-1 ml-5 bg-slate-100"
        style="display: none;"
      >
        <%= for route <- @route.children do %>
          <.route route={route} />
        <% end %>
      </div>
    <% end %>
    """
  end

  attr :route, :map

  def route_actions(assigns) do
    ~H"""
    <div class="">
      <button
        type="button"
        phx-hook="ClipboardHook"
        data-content={get_route_helper(@route)}
        class="px-1 text-sm border border-gray-200 rounded"
        id={route_id(@route) <> "_copy_button"}
      >
        <div class="flex items-center gap-1 before-copied">
          <HeroiconsV1.Outline.clipboard_list class="w-4 h-4" />
          <div class="">Copy helper</div>
        </div>
        <div class="hidden after-copied">Copied!</div>
      </button>
    </div>
    """
  end

  defp get_sections(all_routes) do
    sections =
      Enum.map(all_routes, &List.first(&1.path_list))
      |> Enum.uniq()
      |> Enum.filter(fn path ->
        Enum.find(all_routes, fn route ->
          length(route.path_list) > 1 && List.first(route.path_list) == path
        end)
      end)

    ["root" | sections]
  end

  defp split_path(path) do
    for segment <- String.split(path, "/"), segment != "", do: segment
  end

  defp route_id(route),
    do: "path_#{route.path}_#{route.verb}" |> String.replace("/", "_") |> String.replace(":", "_")

  defp toggle_class(js, id, class) do
    js
    |> JS.dispatch("toggle_class",
      to: id,
      detail: %{
        class: class
      }
    )
  end

  defp get_routes_by_key("root", all_routes, sections) do
    # Here we find the routes that have only one path and no children.
    Enum.filter(all_routes, fn route ->
      !Enum.member?(sections, List.first(route.path_list))
    end)
  end

  defp get_routes_by_key(key, all_routes, _) do
    Enum.filter(all_routes, &(List.first(&1.path_list) == key))
  end

  defp get_verb(route) do
    is_live = route.plug |> Atom.to_string() |> String.contains?("Live")

    if is_live do
      :live
    else
      route.verb
    end
  end

  defp get_verb_color(verb) do
    case verb do
      :get -> "success"
      :live -> "warning"
      :post -> "info"
      :put -> "info"
      :delete -> "danger"
      _ -> "gray"
    end
  end

  defp get_module(%{metadata: %{log_module: module}}), do: format_module(module)
  defp get_module(%{plug: module}), do: format_module(module)

  defp get_action(%{plug_opts: plug_opts}) do
    string = "#{plug_opts}"

    if String.contains?(string, "Elixir.") do
      ""
    else
      ":#{string}"
    end
  end

  defp format_module(module) do
    String.replace(to_string(module), "Elixir.", "")
  end

  defp get_route_action(%{plug_opts: plug_opts}) do
    string = "#{plug_opts}"

    if String.contains?(string, "Elixir.") do
      String.replace(string, "Elixir.", "")
    else
      ":#{string}"
    end
  end

  defp get_route_helper(%{helper: nil}), do: ""

  defp get_route_helper(route) do
    helper = "Routes." <> route.helper <> "_path(@conn, " <> get_route_action(route)

    params =
      Regex.scan(~r/:[0-9a-zA-Z_]*/, route.path)
      |> List.flatten()

    if length(params) > 0 do
      params_string =
        params
        |> Enum.map_join(", ", &String.replace(&1, ":", ""))

      helper <> ", " <> params_string <> ")"
    else
      helper <> ")"
    end
  end
end
