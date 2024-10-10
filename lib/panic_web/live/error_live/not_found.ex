defmodule PanicWeb.ErrorLive.NotFound do
  @moduledoc false
  use PanicWeb, :live_view

  def render(assigns) do
    ~H"""
    <h1 class="text-lg font-semibold mb-8">404 (page not found)</h1>
    <p class="mb-4">Whoops - the page you're looking for doesn't exist.</p>
    <.link class="text-purple-100 underline" navigate={~p"/about/"}>
      Find out more about PANIC!
    </.link>
    """
  end
end
