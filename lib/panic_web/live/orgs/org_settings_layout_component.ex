defmodule PanicWeb.OrgSettingsLayoutComponent do
  @moduledoc """
  A layout for any user setting screen like "Change email", "Change password" etc
  """
  use PanicWeb, :component
  import PanicWeb.OrgLayoutComponent

  # prop current_user, :map
  # prop current_org, :map
  # prop current_page, :atom
  # slot default
  def org_settings_layout(assigns) do
    ~H"""
    <.org_layout
      current_page={:org_settings}
      current_user={@current_user}
      current_org={@current_org}
      current_membership={@current_membership}
      socket={@socket}
    >
      <.container max_width="xl">
        <.h2 class="py-8">
          <%= gettext("%{org_name} settings", org_name: @current_org.name) %>
        </.h2>

        <.sidebar_tabs_container
          current_page={@current_page}
          menu_items={menu_items(@socket, @current_org)}
        >
          <%= render_slot(@inner_block) %>
        </.sidebar_tabs_container>
      </.container>
    </.org_layout>
    """
  end

  defp menu_items(socket, current_org) do
    [
      %{
        name: :edit_org,
        path: Routes.live_path(socket, PanicWeb.EditOrgLive, current_org.slug),
        label: gettext("Edit"),
        icon: :pencil_alt
      },
      %{
        name: :org_team,
        path: Routes.org_team_path(socket, :index, current_org.slug),
        label: gettext("Team"),
        icon: :users
      }
    ]
  end
end
