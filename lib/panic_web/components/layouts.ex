defmodule PanicWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use PanicWeb, :controller` and
  `use PanicWeb, :live_view`; the "display" layout is for the
  full-screen views (watchers, the terminal, the landing page).
  """
  use PanicWeb, :html

  import PanicWeb.PanicComponents

  embed_templates "layouts/*"

  defp nav_links(user) do
    [{"Networks", ~p"/networks"}, {"Installations", ~p"/installations"}] ++
      if user.admin, do: [{"Admin", ~p"/admin"}], else: []
  end
end
