defmodule PetalFramework.Components.StackedLayout do
  use Phoenix.Component
  use PetalComponents
  import PetalFramework.Components.Navbar

  attr :current_page, :atom, required: true
  attr :main_menu_items, :list, default: []
  attr :user_menu_items, :list, default: []
  attr :avatar_src, :string, default: nil
  attr :home_path, :string, default: "/"
  slot(:inner_block)
  slot(:top_right)
  slot(:logo)

  def stacked_layout(assigns) do
    assigns =
      assigns
      |> assign_new(:main_menu_items, fn -> [] end)
      |> assign_new(:user_menu_items, fn -> [] end)
      |> assign_new(:current_user_name, fn -> nil end)
      |> assign_new(:avatar_src, fn -> nil end)
      |> assign_new(:home_path, fn -> "/" end)
      |> assign_new(:top_right, fn -> nil end)

    ~H"""
    <div class="h-screen overflow-y-scroll bg-white dark:bg-gray-900">
      <.navbar {assigns} />

      <%= render_slot(@inner_block) %>
    </div>
    """
  end
end
