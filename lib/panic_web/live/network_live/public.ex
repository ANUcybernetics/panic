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
    slot_id = params |> Map.get("slot_id", "0") |> String.to_integer()
    slot_count = params |> Map.get("slot_count") |> String.to_integer()

    Networks.subscribe(network_id)

    {:noreply,
     socket
     |> assign(:page_title, "Public network view")
     |> assign(:network, network)
     |> assign(:slot_id, slot_id)
     |> assign(:slot_count, slot_count)
     |> assign(:slots, List.duplicate(nil, slot_count))}
  end

  ########
  # info #
  ########

  @impl true
  def handle_info(
    {:run_completed, %Run{cycle_index: 0, status: :succeeded} = run},
    %{assigns: %{live_action: :view, slot_count: slot_count}} = socket
  ) do

    {:noreply, assign(socket, slots: [run] ++ List.duplicate(nil, slot_count - 1), first_run: run)}
  end

  @impl true
  def handle_info(
        {:run_completed, %Run{cycle_index: idx, status: :succeeded} = run},
        %{assigns: %{live_action: :view, slots: slots, slot_count: slot_count}} = socket
      ) do

    if stale_run?(slots, run) do
      {:noreply, socket}
    else
      slots =
        slots
        |> List.replace_at(Integer.mod(idx, slot_count), run)
        |> List.replace_at(Integer.mod(idx + 1, slot_count), nil)
      {:noreply, assign(socket, :slots, slots)}
    end
  end

  @impl true
  def handle_info(
        {:run_completed, %Run{cycle_index: idx, status: :succeeded} = run},
        %{assigns: %{live_action: :screen, slot_id: slot_id, slot_count: slot_count}} = socket
      ) do
    case Integer.mod(idx, slot_count) do
      ^slot_id -> {:noreply, assign(socket, :slots, [run])}
      _ -> {:noreply, socket}
    end
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  def stale_run?(_slots, %Run{cycle_index: 0}), do: false

  def stale_run?(slots, %Run{cycle_index: idx}) do
    case Enum.at(slots, Integer.mod(idx - 1, Enum.count(slots))) do
      nil -> true
      %Run{cycle_index: prev_idx} -> idx != prev_idx + 1
    end
  end

  #############
  # rendering #
  #############

  @impl true
  def render(%{live_action: :view} = assigns) do
    ~H"""
    <div class="bg-black h-screen">
      <div class="relative text-6xl h-60">
        <span class="absolute left-[30px] top-[30px] text-purple-700">
          input: <span :if={@first_run}><%= @first_run.input %></span>
        </span>
        <span class="absolute left-[32px] top-[32px] text-purple-300">
          input: <span :if={@first_run}><%= @first_run.input %></span>
        </span>
      </div>
      <div class="grid gap-2 md:grid-cols-6">
        <%= for run <- @slots do %>
          <PanicWeb.Live.Components.run run={run} show_input={false} />
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def render(%{live_action: :screen} = assigns) do
    ~H"""
    <PanicWeb.Live.Components.run run={List.first(@slots)} show_input={true} />
    """
  end

  # defp push_and_rotate(new_run, slots) do
  #   case Enum.find_index(slots, &is_nil/1) do
  #     nil -> Enum.drop(slots, 1) ++ [new_run]
  #     first_nil -> List.replace_at(slots, first_nil, new_run)
  #   end
  # end

  # defp push_and_reset_if_full(new_run, slots) do
  #   case Enum.find_index(slots, &is_nil/1) do
  #     nil -> [new_run] ++ List.duplicate(nil, Enum.count(slots) - 1)
  #     first_nil -> List.replace_at(slots, first_nil, new_run)
  #   end
  # end
end
