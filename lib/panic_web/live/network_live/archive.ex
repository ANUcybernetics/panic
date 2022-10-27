defmodule PanicWeb.NetworkLive.Archive do
  use PanicWeb, :live_view

  alias Panic.Networks
  alias Panic.Models

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => network_id}, _, socket) do
    network = Networks.get_network!(network_id)

    grouped_runs =
      network
      |> Models.list_runs()
      |> Enum.group_by(fn r -> r.first_run_id end)
      |> Enum.into([])

    {:noreply,
     socket
     |> assign(:page_title, "Network archive")
     |> assign(:network, network)
     |> assign(:grouped_runs, grouped_runs)}
  end
end
