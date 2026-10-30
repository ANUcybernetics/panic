defmodule PanicWeb.Layouts do
  @moduledoc """
  The layouts. The root layout (`layouts/root.html.heex`) is the skeleton the
  router renders around every page. Each LiveView wraps its own content in
  `app/1` (the navbar and a centred column) or `display/1` (the full-screen
  views: watchers, the terminal, the landing page).
  """
  use PanicWeb, :html

  import PanicWeb.PanicComponents

  embed_templates "layouts/root*"

  attr :flash, :map, required: true
  attr :current_user, :any, default: nil, doc: "the signed-in user, if any"
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar gap-2 border-b border-base-300 px-4 sm:px-6 lg:px-8">
      <div class="flex-1">
        <.link
          navigate={if @current_user, do: ~p"/networks", else: ~p"/"}
          aria-label="PANIC! home"
        >
          <.panic_button class="size-12 text-[10px]" />
        </.link>
      </div>
      <span
        :if={@current_user}
        id="current-user-email"
        class="hidden truncate text-sm text-base-content/60 md:inline"
      >
        {@current_user.email}
      </span>
      <nav :if={@current_user} class="flex-none">
        <ul class="menu menu-horizontal hidden gap-1 px-1 sm:flex">
          <li :for={{label, path} <- nav_links(@current_user)}>
            <.link navigate={path}>{label}</.link>
          </li>
          <li>
            <.link href={~p"/sign-out"} method="delete">Sign out</.link>
          </li>
        </ul>
        <details class="dropdown dropdown-end sm:hidden">
          <summary class="btn btn-ghost" aria-label="Menu">
            <.icon name="hero-bars-3" class="size-6" />
          </summary>
          <ul class="menu dropdown-content z-10 mt-2 w-52 rounded-box bg-base-200 p-2 shadow">
            <li :for={{label, path} <- nav_links(@current_user)}>
              <.link navigate={path}>{label}</.link>
            </li>
            <li>
              <.link href={~p"/sign-out"} method="delete">Sign out</.link>
            </li>
          </ul>
        </details>
      </nav>
      <.link :if={!@current_user} navigate={~p"/sign-in"} class="btn btn-ghost">
        Sign in
      </.link>
    </header>
    <main class="px-4 py-10 sm:px-6 sm:py-16 lg:px-8">
      <div class="mx-auto max-w-4xl">
        <.flash_group flash={@flash} />
        {render_slot(@inner_block)}
      </div>
    </main>
    """
  end

  attr :flash, :map, required: true
  slot :inner_block, required: true

  def display(assigns) do
    ~H"""
    <main class="h-dvh overflow-hidden">
      <style>
        :root {
          font-size: 200%;
          /* no scrollbar here, so don't reserve room for one beside the display */
          scrollbar-gutter: auto;
        }
      </style>
      <div>
        <.flash_group flash={@flash} />
        {render_slot(@inner_block)}
      </div>
    </main>
    """
  end

  defp nav_links(user) do
    [{"Networks", ~p"/networks"}, {"Installations", ~p"/installations"}] ++
      if user.admin, do: [{"Admin", ~p"/admin"}], else: []
  end
end
