defmodule PanicWeb.NetworkLive.Public do
  use PanicWeb, :live_view

  alias Panic.Networks
  alias Panic.Models.Run

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :first_run, nil)}
  end

  @impl true
  def handle_params(%{"id" => network_id} = params, _, socket) do
    network = Networks.get_network!(network_id)
    num_slots = Map.get(params, "slots", "1") |> String.to_integer()

    Networks.subscribe(network_id)

    {:noreply,
     socket
     |> assign(:page_title, "Public network view")
     |> assign(:network, network)
     |> assign(:slots, List.duplicate(nil, num_slots))}
  end

  ########
  # info #
  ########

  @impl true
  def handle_info({:run_completed, %Run{status: :succeeded} = run}, %{assigns: %{live_action: :view}} = socket) do
    {:noreply, update(socket, :slots, fn slots -> push_front_drop_last(run, slots) end )}
  end

  @impl true
  def handle_info({:run_completed, %Run{cycle_index: idx, status: :succeeded} = run}, %{assigns: %{live_action: :screen}} = socket) do
    num_screens = 8 # hardcoded for Panic, will generalise later

    if Integer.mod(idx, num_screens) == socket.assigns.screen_id do
      {:noreply, assign(socket, :slots, [run])}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end


  @impl true
  def render(%{live_action: :view} = assigns) do
    ~H"""
    <div class="grid gap-8 md:grid-cols-6">
      <%= for {run, _idx} <- Enum.with_index(@slots) do %>
        <PanicWeb.Live.Components.run run={run} />
      <% end %>
    </div>
    """
  end

  defp push_front_drop_last(new_run, slots), do: [new_run] ++ Enum.drop(slots, -1)
end
