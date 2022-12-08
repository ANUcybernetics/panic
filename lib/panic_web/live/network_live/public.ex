defmodule PanicWeb.NetworkLive.Public do
  use PanicWeb, :live_view

  alias Panic.Networks
  alias Panic.Networks.Analytics
  alias Panic.Models
  alias Panic.Models.Run

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => network_id} = params, _, socket) do
    network = Networks.get_network!(network_id)
    slot_id = params |> Map.get("slot_id", "0") |> String.to_integer()
    slot_count = params |> Map.get("slot_count") |> String.to_integer()

    Networks.subscribe(network_id)

    ## analytics
    {:noreply,
     socket
     |> assign(:page_title, "Public network view")
     |> assign(:network, network)
     |> assign(:analytics, get_analytics(network))
     |> assign(:slot_id, slot_id)
     |> assign(:slots, empty_slots(slot_count))}
  end

  ########
  # info #
  ########

  @impl true
  def handle_info({:run_created, %Run{cycle_index: 0} = run}, socket) do
    {:noreply,
     socket
     |> assign(:first_run, run)
     |> update(:slots, fn slots -> update_slots(slots, run) end)}
  end

  @impl true
  def handle_info({:run_created, run}, socket) do
    {:noreply,
     socket
     |> assign_new(:first_run, fn -> Models.get_run!(run.first_run_id) end)
     |> update(:slots, fn slots -> update_slots(slots, run) end)}
  end

  @impl true
  def handle_info({:run_completed, %Run{status: :succeeded} = run}, socket) do
    {:noreply,
     socket
     |> assign_new(:first_run, fn -> Models.get_run!(run.first_run_id) end)
     ## *super* expensive - refactor asap!
     |> assign(:analytics, get_analytics(socket.assigns.network))
     |> update(:slots, fn slots -> update_slots(slots, run) end)}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  def stale_run?(_slots, %Run{cycle_index: 0}), do: false

  def stale_run?(slots, %Run{cycle_index: idx}) do
    if Enum.any?(slots) do
      case Enum.at(slots, Integer.mod(idx - 1, Enum.count(slots))) do
        nil -> true
        %Run{cycle_index: prev_idx} -> idx != prev_idx + 1
      end
    else
      false
    end
  end

  defp empty_slots(slot_count) do
    List.duplicate(nil, slot_count)
  end

  defp update_slots(slots, %Run{cycle_index: 0} = run) do
    slot_count = Enum.count(slots)
    [run] ++ empty_slots(slot_count - 1)
  end

  defp update_slots(slots, %Run{cycle_index: idx} = run) do
    if stale_run?(slots, run) do
      slots
    else
      slot_count = Enum.count(slots)
      List.replace_at(slots, Integer.mod(idx, slot_count), run)
    end
  end

  defp get_analytics(network) do
    %{
      run_count: Analytics.run_count(network),
      cycle_count: Analytics.cycle_count(network),
      sheep: Analytics.time_to_word(network, "sheep"),
      horse: Analytics.time_to_word(network, "horse"),
      camel: Analytics.time_to_word(network, "camel"),
      kite: Analytics.time_to_word(network, "kite"),
      umbrella: Analytics.time_to_word(network, "umbrella")
    }
  end

  #############
  # rendering #
  #############

  def word_analytics(assigns) do
    ~H"""
    <span>
      <span class="font-noto-color-emoji"><%= @symbol %></span> <%= (100.0 * @ccw / @cycle_count)
      |> trunc()
      |> Integer.to_string() %>%/<%= @ttw |> trunc() |> Integer.to_string() %>τ
    </span>
    """
  end

  def analytics_hud(assigns) do
    assigns =
      Map.put(
        assigns,
        :words,
        [{"🐑", :sheep}, {"🐎", :horse}, {"🐪", :camel}, {"🪁", :kite}, {"☂", :umbrella}, {"✂", :scissors}]
      )

    ~H"""
    <div :if={@analytics.cycle_count != 0} class="flex justify-between p-1">
      <%= for {symbol, word} <- @words do %>
        <.word_analytics
          symbol={symbol}
          ccw={@analytics[word][:ccw]}
          ttw={@analytics[word][:ttw]}
          cycle_count={@analytics.cycle_count}
        />
      <% end %>
      <span>
        TOTAL <%= @analytics.cycle_count |> Integer.to_string() %>C/<%= @analytics.run_count
        |> Integer.to_string() %>R
      </span>
    </div>
    """
  end

  @impl true
  def render(%{live_action: :view} = assigns) do
    ~H"""
    <div class="bg-black h-screen cursor-none overflow-hidden">
      <div class="relative text-4xl h-48">
        <span class="absolute left-[30px] top-[30px] text-purple-700 max-w-fit-content">
          input: <span :if={Map.has_key?(assigns, :first_run)}><%= @first_run.input %></span>
        </span>
        <span class="absolute left-[32px] top-[32px] text-purple-300 max-w-fit-content">
          input: <span :if={Map.has_key?(assigns, :first_run)}><%= @first_run.input %></span>
        </span>
      </div>
      <div class="grid gap-2 md:grid-cols-6">
        <%= for run <- @slots do %>
          <PanicWeb.Live.Components.run run={run} show_input={false} />
        <% end %>
      </div>
      <div class="absolute left-0 bottom-0 right-0 text-lg text-purple-300 backdrop-blur-md bg-white/20">
        <.analytics_hud analytics={@analytics} />
      </div>
    </div>
    """
  end

  @impl true
  def render(%{live_action: :screen} = assigns) do
    ~H"""
    <PanicWeb.Live.Components.run run={Enum.at(@slots, @slot_id)} show_input={true} />
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
