defmodule PetalProWeb.DevLayoutComponent do
  @moduledoc """
  A layout for any user setting screen like "Change email", "Change password" etc
  """
  use PetalProWeb, :component

  # prop current_user, :map
  # prop current_page, :string
  # prop current, :atom
  # slot default
  def dev_layout(assigns) do
    ~H"""
    <.layout
      current_page={@current_page}
      current_user={@current_user}
      type="sidebar"
      main_menu_items={
        [
          %{
            title: "Pages",
            menu_items: PetalProWeb.Menus.build_menu([:dev], @current_user)
          },
          %{
            title: "Emails",
            menu_items:
              PetalProWeb.Menus.build_menu([:dev_email_templates, :dev_sent_emails], @current_user)
          }
        ]
      }
    >
      <%= render_slot(@inner_block) %>
    </.layout>
    """
  end
end
