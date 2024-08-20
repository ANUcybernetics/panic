defmodule PanicWeb.IndexLive do
  use PanicWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <p>Panic is really live now.</p>
    <p :if={@current_user}>Current user: <%= @current_user.email %></p>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event(_event, _unsigned_params, socket) do
    {:noreply, socket}
  end
end
