defmodule PanicWeb.ErrorLive.NotFound do
  @moduledoc false
  use PanicWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>404 (page not found)</.header>
      <p class="mb-4">Whoops - the page you're looking for doesn't exist.</p>
      <.link class="link" navigate={~p"/about/"}>
        Find out more about PANIC!
      </.link>
    </Layouts.app>
    """
  end
end
