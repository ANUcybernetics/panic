defmodule PanicWeb.NetworkLive.Show do
  use PanicWeb, :live_view

  alias Panic.Networks
  alias Panic.Models
  alias Panic.Models.Run
  alias Panic.Models.Platforms.Vestaboard

  @num_slots 6
  @reprompt_seconds 30

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:status, :waiting)
     |> assign(:timer, 0)
     |> assign(:first_run, nil)
     |> assign(:slots, List.duplicate(nil, @num_slots))}
  end

  @impl true
  def handle_params(%{"id" => network_id} = params, _, socket) do
    network = Networks.get_network!(network_id)
    vestaboards? = params |> Map.has_key?("vestaboards")

    Networks.subscribe(network_id)

    {:noreply,
     socket
     |> assign(:page_title, "Show network")
     |> assign(:vestaboards?, vestaboards?)
     |> assign(:network, network)}
  end

  ########
  # info #
  ########

  @impl true
  def handle_info(:decrement_timer, socket) do
    schedule_timer_decrement(socket.assigns.timer)
    {:noreply, update(socket, :timer, &(&1 - 1))}
  end

  # handler for whenever a *first* run is created
  @impl true
  def handle_info({:run_created, %Run{cycle_index: 0} = run}, socket) do
    schedule_timer_decrement(@reprompt_seconds)

    {:noreply,
     socket
     |> assign(:status, :running)
     |> assign(:timer, @reprompt_seconds)
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

      # gross, just for testing
      if socket.assigns.vestaboards? and run.model == "replicate:rmokady/clip_prefix_caption" do
        {:ok, _} = Vestaboard.send_text(:panic_4, run.output)
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

  defp stale_run?(_slots, %Run{cycle_index: 0}), do: false
  defp stale_run?(slots, %Run{cycle_index: idx}) do
    case Enum.at(slots, mod_num_slots(idx - 1)) do
      nil -> true
      %Run{cycle_index: prev_idx} -> idx != prev_idx + 1
    end
  end

  defp schedule_timer_decrement(timer) do
    if timer > 0 do
      Process.send_after(self(), :decrement_timer, 1000)
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
          terminal={false}
        />

        <div :if={@first_run} class="mb-4">
          <span class="font-bold"><%= @first_run.input %></span>
        </div>

        <PanicWeb.Live.Components.slots_grid slots={@slots} />
      </.container>
    </.layout>
    """
  end

  @impl true
  def render(%{live_action: :terminal} = assigns) do
    ~H"""
    <div class="relative w-screen h-screen bg-black text-purple-300">
      <div class="w-2/3 pt-24 mx-auto">
        <.live_component
          module={PanicWeb.NetworkLive.InitialPromptComponent}
          id="initial-prompt-input"
          network={@network}
          terminal={true}
          disabled={assigns.timer > 0}
        />
        <div class="mt-4">current input: <span :if={@first_run}><%= @first_run.input %></span></div>
        <div class="mt-4" :if={@timer > 0}>(<%= @timer %>s until ready to go again)</div>
        <div class="absolute bottom-[20px] right-[20px]"><%= @status %></div>
        <span class="absolute left-[20px] bottom-[20px] text-2xl text-purple-700 text-left">Panic</span>
        <span class="absolute left-[21px] bottom-[21px] text-2xl text-purple-300 text-left">Panic</span>
      </div>

      <div class="hidden">
        <PanicWeb.Live.Components.slots_grid slots={@slots} />
      </div>
    </div>
    """
  end
end
