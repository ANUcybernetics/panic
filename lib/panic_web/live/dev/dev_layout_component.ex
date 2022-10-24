defmodule PanicWeb.DevLayoutComponent do
  @moduledoc """
  A layout for any user setting screen like "Change email", "Change password" etc
  """
  use PanicWeb, :component

  attr :current_user, :map
  attr :current_page, :atom
  slot(:inner_block)

  def dev_layout(assigns) do
    ~H"""
    <.layout
      current_page={@current_page}
      current_user={@current_user}
      type="sidebar"
      main_menu_items={[
        %{
          title: "Pages",
          menu_items: [
            PanicWeb.Menus.get_link(:dev, @current_user),
            %{
              name: :resources,
              label: "Resources",
              path: Routes.live_path(PanicWeb.Endpoint, PanicWeb.DevResourcesLive),
              icon: :clipboard_list
            }
          ]
        },
        %{
          title: "Emails",
          menu_items:
            PanicWeb.Menus.build_menu([:dev_email_templates, :dev_sent_emails], @current_user)
        }
      ]}
    >
      <%= render_slot(@inner_block) %>
    </.layout>
    """
  end
end
