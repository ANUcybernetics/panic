defmodule PanicWeb.NetworkLive.Show do
  use PanicWeb, :live_view

  alias Panic.{Networks, Models}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :cycle_status, :stopped)}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    network = Networks.get_network!(id)
    models = network.models
    cycle = List.duplicate(nil, Enum.count(models))

    {:noreply,
     socket
     |> assign(:page_title, "Show network")
     |> assign(:network, network)
     |> assign(:cycle, cycle)}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply,
     push_patch(socket, to: Routes.network_show_path(socket, :show, socket.assigns.network))}
  end

  @impl true
  def handle_event("start_cycle", _, socket) do
    IO.puts("starting...")
    {:noreply, assign(socket, :cycle_status, :running)}
  end

  @impl true
  def handle_event("stop_cycle", _, socket) do
    IO.puts("stopping...")
    {:noreply, assign(socket, :cycle_status, :stopped)}
  end
end
