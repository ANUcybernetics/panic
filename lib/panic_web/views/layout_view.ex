defmodule PanicWeb.LayoutView do
  use PanicWeb, :view
  require Logger

  # Phoenix LiveDashboard is available only in development by default,
  # so we instruct Elixir to not warn if the dashboard route is missing.
  @compile {:no_warn_undefined, {Routes, :live_dashboard_path, 2}}

  def app_name, do: Panic.config(:app_name)

  def title(%{assigns: %{page_title: page_title}}), do: page_title

  def title(conn) do
    if is_public_page(conn.request_path) do
      Logger.warn(
        "Warning: no title defined for path #{conn.request_path}. Defaulting to #{app_name()}. Assign `page_title` in controller action or live view mount to fix."
      )
    end

    app_name()
  end

  def description(%{assigns: %{meta_description: meta_description}}), do: meta_description

  def description(conn) do
    if conn.request_path == "/" do
      Panic.config(:seo_description)
    else
      if is_public_page(conn.request_path) do
        Logger.warn(
          "Warning: no meta description for public path #{conn.request_path}. Assign `meta_description` in controller action or live view mount to fix."
        )
      end

      ""
    end
  end

  def og_image(%{assigns: %{og_image: og_image}}), do: og_image
  def og_image(conn), do: Routes.static_url(conn, "/images/open-graph.png")

  def current_page_url(%{host: host, request_path: request_path}),
    do: "https://" <> host <> request_path

  def current_page_url(_conn), do: PanicWeb.Endpoint.url()

  def twitter_creator(%{assigns: %{twitter_creator: twitter_creator}}), do: twitter_creator
  def twitter_creator(_conn), do: twitter_site(%{})

  def twitter_site(%{assigns: %{twitter_site: twitter_site}}), do: twitter_site

  def twitter_site(_conn) do
    if Panic.config(:twitter_url) do
      "@" <> (Panic.config(:twitter_url) |> String.split("/") |> List.last())
    else
      ""
    end
  end

  def is_public_page(request_path) do
    request_path != "/" &&
      PanicWeb.Menus.public_menu_items()
      |> Enum.map(& &1.path)
      |> Enum.find(&(&1 == request_path))
  end
end
