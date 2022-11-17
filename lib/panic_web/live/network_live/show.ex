defmodule PanicWeb.NetworkLive.Show do
  use PanicWeb, :live_view

  alias Panic.Networks
  alias Panic.Models
  alias Panic.Models.Run

  @num_slots 6

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:status, :waiting)
     |> assign(:first_run, nil)
     |> assign(:slots, List.duplicate(nil, @num_slots))}
  end

  @impl true
  def handle_params(%{"id" => network_id}, _, socket) do
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

  # handler for whenever a *first* run is created
  @impl true
  def handle_info({:run_created, %Run{cycle_index: 0} = run}, socket) do
    {:noreply,
     socket
     |> assign(:status, :running)
     |> assign(:first_run, run)
     |> assign(:slots, [run] ++ List.duplicate(nil, @num_slots - 1))}
  end

  # handler for whenever a non-first run is started.
  @impl true
  def handle_info({:run_created, %Run{cycle_index: idx} = run}, socket) do
    {:noreply,
     socket
     |> assign(:status, :running)
     |> assign(:slots, List.replace_at(socket.assigns.slots, mod_num_slots(idx), run))}
  end

  # Handler for whenever a run is completed (i.e. platform API has returned a result)
  @impl true
  def handle_info({:run_completed, %Run{cycle_index: idx, status: status} = run}, socket) do
    if stale_run?(socket.assigns.slots, run) do
      {:noreply, socket}
    else
      # if the completed run was successful, create & dispatch the new one
      if socket.assigns.status == :running and status == :succeeded do
        {:ok, next_run} = Models.create_next_run(socket.assigns.network, run)
        Models.dispatch_run(next_run)
        Networks.broadcast(next_run.network_id, {:run_created, %{next_run | status: :running}})
      end

      {:noreply,
       assign(socket, :slots, List.replace_at(socket.assigns.slots, mod_num_slots(idx), run))}
    end
  end

  @impl true
  def handle_info({:stop_cycle}, socket) do
    {:noreply, assign(socket, :status, :waiting)}
  end

  ##########
  # events #
  ##########

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply,
     push_patch(socket, to: Routes.network_show_path(socket, :show, socket.assigns.network))}
  end

  @impl true
  def handle_event("stop_cycle", _, socket) do
    {:noreply, assign(socket, :status, :waiting)}
  end

  defp mod_num_slots(n), do: Integer.mod(n, @num_slots)

  defp stale_run?(slots, run) do
    if Enum.any?(slots) do
      max =
        slots
        |> Enum.reject(&is_nil/1)
        |> Enum.map(&Map.get(&1, :updated_at))
        |> Enum.max(Date)

      Date.compare(max, run.updated_at) == :gt
    else
      false
    end
  end

  ###########
  # display #
  ###########

  @impl true
  def render(%{live_action: :show} = assigns) do
    ~H"""
    <.layout current_page={:show_network} current_user={@current_user} type="stacked">
      <.container class="py-16">
        <.page_header title={@network.name}></.page_header>

        <.live_component
          module={PanicWeb.NetworkLive.InitialPromptComponent}
          id="initial-prompt-input"
          network={@network}
          show_buttons={true}
        />

        <div :if={@first_run} class="mb-4">
          <span class="font-bold">input: <%= @first_run.input %></span>
        </div>

        <PanicWeb.Live.Components.slots_grid slots={@slots} />
      </.container>
    </.layout>
    """
  end

  @impl true
  def render(%{live_action: :terminal} = assigns) do
    ~H"""
    <div class="w-screen h-screen grid place-items-center">
      <div class="w-2/3">
        <.live_component
          module={PanicWeb.NetworkLive.InitialPromptComponent}
          id="initial-prompt-input"
          network={@network}
          show_buttons={false}
        />
      </div>

      <div :if={@first_run} class="mb-4">
        <span class="font-bold">input: <%= @first_run.input %></span>
      </div>

      <div class="hidden">
        <PanicWeb.Live.Components.slots_grid slots={@slots} />
      </div>
    </div>
    """
  end
end
