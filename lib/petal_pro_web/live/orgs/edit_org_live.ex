defmodule PetalProWeb.EditOrgLive do
  use PetalProWeb, :live_view
  alias PetalPro.Orgs
  import PetalProWeb.OrgSettingsLayoutComponent

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        changeset: Orgs.change_org(socket.assigns.current_org, %{}),
        page_title: gettext("Editing %{org_name", org_name: socket.assigns.current_org.name)
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.org_settings_layout
      current_page={:edit_org}
      current_user={@current_user}
      current_org={@current_org}
      current_membership={@current_membership}
      socket={@socket}
    >
      <.live_component
        module={PetalProWeb.OrgFormComponent}
        id={:edit}
        action={:edit}
        org={@current_org}
        return_to={Routes.live_path(@socket, PetalProWeb.EditOrgLive, @current_org.slug)}
        current_user={@current_user}
      />
    </.org_settings_layout>
    """
  end
end
