defmodule PanicWeb.ErrorLive.NotFound do
  @moduledoc false
  use PanicWeb, :live_view

  def render(assigns) do
    ~H"""
    <h1 class="text-lg font-semibold mb-8">404 - Page Not Found</h1>
    <p class="mb-4">The page you're looking for doesn't exist.</p>
    <p class="mb-4">Whoops.</p>
    """
  end
end
