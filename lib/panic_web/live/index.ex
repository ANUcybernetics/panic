defmodule PanicWeb.IndexLive do
  @moduledoc false
  use PanicWeb, :live_view

  import PanicWeb.PanicComponents

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative w-dvw h-dvh grid place-items-center">
      <.link href={(@current_user && ~p"/users/#{@current_user}") || ~p"/sign-in"}>
        <.panic_button class="size-[60vmin] text-[12vmin]"></.panic_button>
      </.link>
      <.link
        navigate={~p"/about"}
        class="absolute bottom-4 right-4 text-zinc-600 hover:text-purple-300"
      >
        About
      </.link>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket, layout: {PanicWeb.Layouts, :display}}
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
