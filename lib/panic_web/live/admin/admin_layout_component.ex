defmodule PanicWeb.AdminLayoutComponent do
  use PanicWeb, :component
  alias PanicWeb.Menus
  alias PanicWeb.Endpoint

  attr :current_user, :map, required: true
  attr :current_page, :atom
  slot(:inner_block)

  def admin_layout(assigns) do
    ~H"""
    <.layout
      current_page={@current_page}
      current_user={@current_user}
      type="sidebar"
      sidebar_title="Admin"
      main_menu_items={menu_items(@current_user)}
    >
      <.container max_width="xl" class="my-10">
        <%= render_slot(@inner_block) %>
      </.container>
    </.layout>
    """
  end

  def menu_items(current_user) do
    [
      %{
        title: "Admin",
        menu_items: [
          Menus.get_link(:admin_users, current_user),
          %{
            name: :logs,
            label: "Logs",
            path: Routes.logs_path(Endpoint, :index),
            icon: :eye
          },
          %{
            name: :admin_jobs,
            label: "Jobs",
            path: Routes.live_path(Endpoint, PanicWeb.AdminJobsLive),
            icon: :server
          }
        ]
      },
      %{
        title: "Server",
        menu_items: [
          %{
            name: :server,
            label: "Live dashboard",
            path: Routes.live_dashboard_path(Endpoint, :home),
            icon: :chart_square_bar
          }
        ]
      }
    ]
  end
end
