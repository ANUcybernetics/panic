defmodule PetalProWeb.AdminLayoutComponent do
  use PetalProWeb, :component
  alias PetalProWeb.Menus

  # prop current_user, :any
  # prop current_page, :atom
  # data tabs, :list
  # slot default
  def admin_layout(assigns) do
    assigns =
      assign_new(assigns, :menu_items, fn ->
        Menus.build_menu(
          [
            :admin_users,
            :logs,
            :server
          ],
          assigns.current_user
        )
      end)

    ~H"""
    <.layout
      current_page={@current_page}
      current_user={@current_user}
      type="sidebar"
      sidebar_title="Admin"
      main_menu_items={@menu_items}
    >
      <.container max_width="xl" class="my-10">
        <%= render_slot(@inner_block) %>
      </.container>
    </.layout>
    """
  end
end
