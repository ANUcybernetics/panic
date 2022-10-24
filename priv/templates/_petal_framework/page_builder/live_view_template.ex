defmodule PanicWeb.<%= @module_name %> do
  use PanicWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "<%= @title %>", meta_description: "")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.layout current_page={:<%= @menu_item_name %>} current_user={@current_user} type="<%= @layout %>">
      <.container class="my-10">
        <.h2><%= @title %></.h2>
      </.container>
    </.layout>
    """
  end
end
