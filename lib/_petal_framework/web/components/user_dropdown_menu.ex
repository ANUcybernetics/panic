defmodule PetalFramework.Components.UserDropdownMenu do
  use Phoenix.Component
  alias PetalComponents.Heroicons
  import PetalComponents.Avatar
  import PetalComponents.Dropdown

  # prop user_menu_items, :list
  # prop current_user_name, :string
  def user_menu_dropdown(assigns) do
    assigns =
      assigns
      |> assign_new(:avatar_src, fn -> nil end)

    ~H"""
    <.dropdown>
      <:trigger_element>
        <div class="inline-flex items-center justify-center w-full align-middle focus:outline-none">
          <%= if @current_user_name || @avatar_src do %>
            <.avatar name={@current_user_name} src={@avatar_src} size="sm" random_color />
          <% else %>
            <.avatar size="sm" />
          <% end %>

          <Heroicons.Solid.chevron_down class="w-4 h-4 ml-1 -mr-1 text-gray-400 dark:text-gray-100" />
        </div>
      </:trigger_element>
      <%= for menu_item <- @user_menu_items do %>
        <.dropdown_menu_item
          link_type={if menu_item[:method], do: "a", else: "live_redirect"}
          method={if menu_item[:method], do: menu_item[:method], else: nil}
          to={menu_item.path}
        >
          <%= if is_atom(menu_item.icon) do %>
            <Heroicons.Outline.render icon={menu_item.icon} class="w-5 h-5 text-gray-500" />
          <% end %>

          <%= if is_binary(menu_item.icon) do %>
            <%= Phoenix.HTML.raw(menu_item.icon) %>
          <% end %>

          <%= menu_item.label %>
        </.dropdown_menu_item>
      <% end %>
    </.dropdown>
    """
  end
end
