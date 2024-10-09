defmodule PanicWeb.IndexLive do
  @moduledoc false
  use PanicWeb, :live_view

  import PanicWeb.PanicComponents

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-dvw h-dvh grid place-items-center">
      <.link navigate={(@current_user && ~p"/users/#{@current_user}") || ~p"/sign-in"}>
        <div class="size-[60vmin] text-[12vmin] rounded-full grid place-items-center animate-breathe bg-rose-500">
          <.shadowed_text>PANIC!</.shadowed_text>
        </div>
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
