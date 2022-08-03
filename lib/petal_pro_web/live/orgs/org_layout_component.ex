defmodule PetalProWeb.OrgLayoutComponent do
  @moduledoc """
  A layout for any page scoped to an org. eg "Org dashboard", "Org settings", etc.
  """
  use PetalProWeb, :component

  # prop socket, :map
  # prop current_user, :map
  # prop current_page, :atom
  # prop current_org, :map
  # slot default
  def org_layout(assigns) do
    ~H"""
    <.layout
      current_page={@current_page}
      current_user={@current_user}
      main_menu_items={build_menu(@socket, @current_membership, @current_org)}
      type="sidebar"
      sidebar_title={@current_org.name}
    >
      <%= render_slot(@inner_block) %>
    </.layout>
    """
  end

  defp build_menu(socket, membership, org) do
    case membership.role do
      "member" ->
        [
          get_link(:org_dashboard, socket, org)
        ]

      "admin" ->
        [
          get_link(:org_dashboard, socket, org),
          get_link(:org_settings, socket, org)
        ]
    end
  end

  defp get_link(:org_dashboard, socket, org) do
    %{
      name: :org_dashboard,
      path: Routes.live_path(socket, PetalProWeb.OrgDashboardLive, org.slug),
      label: "Dashboard",
      icon: :office_building
    }
  end

  defp get_link(:org_settings, socket, org) do
    %{
      name: :org_settings,
      path: Routes.live_path(socket, PetalProWeb.EditOrgLive, org.slug),
      label: "Settings",
      icon: :cog
    }
  end
end
