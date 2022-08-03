defmodule PetalProWeb.PageController do
  use PetalProWeb, :controller

  def landing_page(conn, _params) do
    render(conn)
  end

  def license(conn, _) do
    render(conn)
  end

  def privacy(conn, _) do
    render(conn)
  end
end
