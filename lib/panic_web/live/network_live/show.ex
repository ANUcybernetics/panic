defmodule PanicWeb.NetworkLive.Show do
  use PanicWeb, :live_view

  alias Panic.Networks
  alias Panic.Models.Run

  @num_slots 8

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :cycle_status, :stopped)}
  end

  @impl true
  def handle_params(%{"id" => network_id}, _, socket) do
    network = Networks.get_network!(network_id)

    # create, but don't persist to the db until it starts (it's not valid, anyway)
    first_run = %Run{model: List.first(network.models), network_id: network_id}

    Networks.subscribe(network_id)

    {:noreply,
     socket
     |> assign(:page_title, "Show network")
     |> assign(:network, network)
     |> assign(:first_run, first_run)
     |> assign_new(:cycle, fn -> List.duplicate(nil, @num_slots) end)
    }
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

  @impl true
  def handle_info({"run_complete", image_url}, socket) do
    IO.inspect "from the handler it's #{image_url}"
    {:noreply, socket}
  end
end
