defmodule PanicWeb.OrgDashboardLive do
  @moduledoc """
  Show a dashborad for a single org. Current user must be a member of the org.
  """
  use PanicWeb, :live_view
  import PanicWeb.OrgLayoutComponent

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        page_title: socket.assigns.current_org.name
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.org_layout
      current_page={:org_dashboard}
      current_user={@current_user}
      current_org={@current_org}
      current_membership={@current_membership}
      socket={@socket}
    >
      <.container max_width="xl" class="my-10">
        <.h2><%= @current_org.name %></.h2>

        <div class="px-4 py-8 sm:px-0">
          <div class="flex items-center justify-center border-4 border-gray-300 border-dashed rounded-lg dark:border-gray-800 h-96">
            <div class="text-xl"><%= gettext("Organisation dashboard") %></div>
          </div>
        </div>
      </.container>
    </.org_layout>
    """
  end
end
