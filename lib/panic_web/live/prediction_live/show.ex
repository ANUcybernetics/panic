defmodule PanicWeb.PredictionLive.Show do
  use PanicWeb, :live_view

  alias Panic.{Networks, Predictions}
  import PanicWeb.NetworkComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(
        %{
          "network_id" => network_id,
          "prediction_id" => _prediction_id,
          "modulo" => slot_modulo,
          "offset" => slot_offset
        },
        _,
        socket
      ) do
    if connected?(socket), do: Networks.subscribe(network_id)

    {:noreply,
     socket
     |> assign(:page_title, "Show Prediction (live #{slot_modulo}/#{slot_offset})")
     |> assign(:incoming, nil)
     |> assign(:slot_modulo, String.to_integer(slot_modulo))
     |> assign(:slot_offset, String.to_integer(slot_offset))
     |> assign(:prediction, nil)}
  end

  @impl true
  def handle_params(%{"network_id" => _network_id, "prediction_id" => prediction_id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Show Prediction")
     |> assign(:incoming, nil)
     |> assign(:prediction, Predictions.get_prediction!(prediction_id))}
  end

  @impl true
  def handle_info({:prediction_incoming, run_index}, socket) do
    {:noreply,
     assign(
       socket,
       :incoming,
       slot_match?(run_index, socket.assigns.slot_modulo, socket.assigns.slot_offset)
     )}
  end

  @impl true
  def handle_info({:new_prediction, prediction}, socket) do
    # TODO refactor to a nice `with`
    if slot_match?(prediction.run_index, socket.assigns.slot_modulo, socket.assigns.slot_offset) do
      {:noreply, assign(socket, :prediction, prediction)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <.prediction_card prediction={@prediction} incoming={@incoming} />
    """
  end

  defp slot_match?(run_index, slot_modulo, slot_offset) do
    Integer.mod(run_index, slot_modulo) == slot_offset
  end
end
