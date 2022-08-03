defmodule PetalProWeb.<%= @module_name %> do
  use PetalProWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.layout current_page={:<%= @menu_item_name %>} current_user={@current_user} type="<%= @layout %>">
      <.container max_width="xl" class="my-10">
        <.h2><%= @title %></.h2>
      </.container>
    </.layout>
    """
  end
end
