defmodule PanicWeb.UserSettingsLayoutComponent do
  @moduledoc """
  A layout for any user setting screen like "Change email", "Change password" etc
  """
  use PanicWeb, :component

  # prop current_user, :map
  # prop current, :atom
  # slot default
  def settings_layout(assigns) do
    ~H"""
    <.layout current_page={@current} current_user={@current_user} type="sidebar">
      <.container max_width="xl">
        <.h2 class="py-8">
          Settings
        </.h2>

        <.sidebar_tabs_container current_page={@current} menu_items={menu_items(@current_user)}>
          <%= render_slot(@inner_block) %>
        </.sidebar_tabs_container>
      </.container>
    </.layout>
    """
  end

  defp menu_items(current_user) do
    [
      :edit_profile,
      :edit_email,
      :edit_password,
      :edit_notifications,
      :edit_totp,
      :org_invitations
    ]
    |> PanicWeb.Menus.build_menu(current_user)
  end
end
