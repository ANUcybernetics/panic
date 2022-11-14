defmodule PanicWeb.NetworkLive.Public do
  use PanicWeb, :live_view

  alias Panic.Networks
  alias Panic.Models
  alias Panic.Models.Run

  @num_slots 8 # this could be passed as a parameter

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:first_run, nil)
     |> assign(:slots, List.duplicate(nil, @num_slots))}
  end

  @impl true
  def handle_params(%{"id" => network_id, "screen_id" => screen_id}, _, socket) do
    network = Networks.get_network!(network_id)

    Networks.subscribe(network_id)

    {:noreply,
     socket
     |> assign(:page_title, "Show network")
     |> assign(:network, network)}
  end

  ########
  # info #
  ########

  # Handler for whenever a run is completed (i.e. platform API has returned a result)
  @impl true
  def handle_info({:run_completed, %Run{cycle_index: idx, status: :succeeded} = run}, socket) do
    # todo could this be done in a guard clause?
    if Integer.mod(idx, @num_slots) == 0 do
      {:noreply, assign(socket, :run, run)}
    else
      {:noreply, socket}
    end
  end
end
