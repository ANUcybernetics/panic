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
     |> assign(:slots, List.duplicate(nil, @num_slots))
     |> push_event("focus_input", %{id: "panic-main-textinput"})}
  end

  @impl true
  def handle_params(%{"id" => network_id} = params, _, socket) do
    network = Networks.get_network!(network_id)

    vestaboards =
      params
      |> Map.get("vestaboards", "")
      |> String.graphemes()
      |> Enum.map(&String.to_atom("panic_" <> &1))

    Networks.subscribe(network_id)

    {:noreply,
     socket
     |> assign(:page_title, "Show network")
     |> assign(:vestaboards, vestaboards)
     |> assign(:network, network)}
  end

  ########
  # info #
  ########

  @impl true
  def handle_info(:decrement_timer, socket) do
    schedule_timer_decrement(socket.assigns.timer)

    if socket.assigns.timer == 0 do
      {:noreply,
       socket
       |> update(:timer, &(&1 - 1))
       |> push_event("focus_input", %{id: "panic-main-textinput"})}
    else
      {:noreply, update(socket, :timer, &(&1 - 1))}
    end
  end

  # handler for whenever a *first* run is created
  @impl true
  def handle_info({:run_created, %Run{cycle_index: 0} = run}, socket) do
    schedule_timer_decrement(@reprompt_seconds)

    Vestaboard.clear_all()

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
      send_to_vestaboard(socket.assigns.vestaboards, run)

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

  def stale_run?(_slots, %Run{cycle_index: 0}), do: false

  def stale_run?(slots, %Run{cycle_index: idx}) do
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

  defp send_to_vestaboard([], _run), do: :pass

  defp send_to_vestaboard(vestaboards, run) do
    ## hardcoded, will make more generalisable later
    idx =
      run.cycle_index
      |> Integer.mod(Enum.count(vestaboards) * 3)
      |> Integer.floor_div(3)

    if run.model == "replicate:rmokady/clip_prefix_caption" do
      vestaboards
      |> Enum.at(idx)
      |> Vestaboard.send_text(run.output)
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
          id="initial-prompt"
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
    <div class="relative p-36 w-screen h-screen bg-black text-purple-300 cursor-none">
      <.live_component
        module={PanicWeb.NetworkLive.InitialPromptComponent}
        id="initial-prompt"
        network={@network}
        terminal={true}
        timer={@timer}
      />
      <div :if={@first_run} class="mt-4">current input: <%= @first_run.input %></div>

      <div class="hidden">
        <PanicWeb.Live.Components.slots_grid slots={@slots} />
      </div>

      <.status_footer status={@status} />
    </div>
    """
  end

  def status_footer(assigns) do
    ~H"""
    <div class="absolute bottom-[20px] right-[20px] text-2xl"><%= @status %></div>
    <span class="absolute left-[20px] bottom-[20px] text-2xl text-purple-700 text-left">
      Panic
    </span>
    <span class="absolute left-[21px] bottom-[21px] text-2xl text-purple-300 text-left">
      Panic
    </span>
    """
  end
end
