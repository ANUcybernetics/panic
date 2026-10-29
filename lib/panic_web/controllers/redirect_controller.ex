defmodule PanicWeb.RedirectController do
  @moduledoc false
  use PanicWeb, :controller

  def networks(conn, _params), do: redirect(conn, to: ~p"/networks")
end
