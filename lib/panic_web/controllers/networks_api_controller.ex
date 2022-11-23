defmodule PanicWeb.NetworksAPIController do
  use PanicWeb, :controller

  alias Panic.Networks

  def show(conn, %{"id" => id}) do
    network = Networks.get_network_preload_runs!(id)

    render(conn, "show.json", network: network)
  end
end
