defmodule PetalFramework.LiveViews.PageBuilderLive do
  @moduledoc """
  A dev-only live view that builds new pages by copying templates and modifying the router.
  """
  use Phoenix.LiveView
  use PetalComponents
  alias PetalFramework.PageBuilder
  alias PetalFramework.PageChangeset

  @impl true
  def mount(params, _session, socket) do
    path_list =
      if params["path_root"] do
        Enum.filter([params["path_root"], params["path_child"]], & &1)
      else
        ["test"]
      end

    underscored_name = List.last(path_list) |> String.replace("-", "_")
    camel_case_name = Macro.camelize(underscored_name)
    human_name = Phoenix.Naming.humanize(underscored_name)

    changeset =
      PageChangeset.build(%{
        type: "live",
        layout: "public",
        route_section: nil,
        route_path: "/" <> Enum.join(path_list, "/"),
        controller_function_name: underscored_name,
        live_view_module_name: camel_case_name <> "Live",
        page_title: human_name
      })

    {:ok,
     assign(socket,
       route_sections: get_route_sections(changeset),
       changeset: changeset
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.container max_width="sm" class="my-12">
      <.h2>Page builder</.h2>

      <.p class="text-sm">
        The page builder acts like a generator, but using a web interface. Use this to quickly build a basic page that you can work off.
      </.p>

      <.form
        :let={f}
        for={@changeset}
        as={:page}
        phx-submit="create-page"
        phx-change="change-page"
        class="mt-8"
      >
        <.form_field type="text_input" form={f} field={:route_path} label="Route path" />

        <.form_field
          type="radio_group"
          options={["Live view": "live", "Traditional static view": "static"]}
          form={f}
          label="Page type"
          field={:type}
        />

        <.form_field
          type="radio_group"
          options={[
            "Public (for public pages)": "public",
            "Sidebar (sidebar and navbar - usually for private pages)": "sidebar",
            "Stacked (a navbar - usually for private pages)": "stacked"
          ]}
          form={f}
          field={:layout}
        />

        <.form_field
          type="select"
          options={@route_sections}
          form={f}
          field={:route_section}
          label="Whereabouts in the router do you want the route?"
        />

        <div class={if @changeset.changes.type == "static", do: "", else: "hidden"}>
          <.form_field
            type="text_input"
            form={f}
            field={:controller_function_name}
            label="PageController function name for the action (the template will also be named this)"
            placeholder="eg. about_us"
          />
        </div>

        <div class={if @changeset.changes.type == "live", do: "", else: "hidden"}>
          <.form_field
            type="text_input"
            form={f}
            field={:live_view_module_name}
            label="Live view module name"
            placeholder="eg. AboutUsLive"
          />
        </div>

        <.form_field
          type="text_input"
          form={f}
          field={:page_title}
          label="Page title"
          placeholder="eg. About us"
        />

        <div class="flex justify-end">
          <.button>Build</.button>
        </div>
      </.form>
    </.container>
    """
  end

  @impl true
  def handle_event("change-page", %{"page" => params}, socket) do
    changeset = PageChangeset.build(params)

    {:noreply,
     assign(socket, changeset: changeset, route_sections: get_route_sections(changeset))}
  end

  @impl true
  def handle_event("create-page", %{"page" => params}, socket) do
    changeset = PageChangeset.build(params)

    case PageChangeset.validate(changeset) do
      {:ok, page} ->
        create_page(page)

        socket =
          socket
          |> put_flash(:info, "Done. Wait for reload.")
          |> push_redirect(to: page.route_path)

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def create_page(%{type: "static"} = page) do
    PageBuilder.make_changes([
      [
        action: :inject_after_target_line,
        file_path: "lib/panic_web/router.ex",
        target_line: page.route_section,
        code: """
        get "#{page.route_path}", PageController, :#{page.controller_function_name}
        """
      ],
      [
        action: :copy_template,
        template: "page_template.html.heex",
        destination_file_path:
          "lib/panic_web/templates/page/#{page.controller_function_name}.html.heex",
        assigns: %{
          title: page.page_title,
          layout: page.layout,
          menu_item_name: page.controller_function_name
        }
      ],
      [
        action: :inject_before_final_end,
        file_path: "lib/panic_web/controllers/page_controller.ex",
        code: """

          def #{page.controller_function_name}(conn, _params) do
            render(conn, page_title: "#{page.page_title}")
          end
        """
      ]
    ])
  end

  def create_page(%{type: "live"} = page) do
    PageBuilder.make_changes([
      [
        action: :inject_after_target_line,
        file_path: "lib/panic_web/router.ex",
        target_line: page.route_section,
        code: """
        live "#{page.route_path}", #{page.live_view_module_name}
        """
      ],
      [
        action: :copy_template,
        template: "live_view_template.ex",
        destination_file_path:
          "lib/panic_web/live/#{Macro.underscore(page.live_view_module_name)}.ex",
        assigns: %{
          title: page.page_title,
          layout: page.layout,
          module_name: page.live_view_module_name,
          menu_item_name: "change_me"
        }
      ]
    ])
  end

  defp get_route_sections(changeset) do
    router = File.read!("lib/panic_web/router.ex")

    case changeset.changes.type do
      "live" ->
        Regex.scan(~r/page_builder:live:(\S+)/, router)
        |> Enum.map(&{List.last(&1) |> Phoenix.Naming.humanize(), List.first(&1)})

      "static" ->
        Regex.scan(~r/page_builder:static:(\S+)/, router)
        |> Enum.map(&{List.last(&1) |> Phoenix.Naming.humanize(), List.first(&1)})
    end
  end
end
