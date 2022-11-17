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
        {:run_completed, %Run{cycle_index: idx, status: :succeeded} = run},
        %{assigns: %{live_action: :view, slots: slots, slot_count: slot_count}} = socket
      ) do
    slots =
      slots
      |> List.replace_at(Integer.mod(idx, slot_count), run)
      |> List.replace_at(Integer.mod(idx + 1, slot_count), nil)

    if idx == 0 do
      {:noreply, assign(socket, slots: slots, first_run: run)}
    else
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

  #############
  # rendering #
  #############

  @impl true
  def render(%{live_action: :view} = assigns) do
    ~H"""
    <div class="text-4xl p-8 mb-4">input: <span :if={@first_run}><%= @first_run.input %></span></div>
    <div class="grid gap-4 md:grid-cols-4">
      <%= for run <- @slots do %>
        <PanicWeb.Live.Components.run run={run} />
      <% end %>
    </div>
    """
  end

  @impl true
  def render(%{live_action: :screen} = assigns) do
    ~H"""
    <PanicWeb.Live.Components.run run={List.first(@slots)} />
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
