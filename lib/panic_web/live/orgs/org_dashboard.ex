defmodule PanicWeb.OrgDashboardLive do
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
          <div class="border-4 border-dashed border-gray-300 dark:border-gray-800 rounded-lg h-96 flex items-center justify-center">
            <div class="text-xl">Organisation dashboard</div>
          </div>
        </div>
      </.container>
    </.org_layout>
    """
  end
end
