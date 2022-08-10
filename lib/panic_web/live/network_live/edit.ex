defmodule PanicWeb.NetworkLive.Edit do
  use PanicWeb, :live_view

  alias Panic.{Networks, Models}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    network = Networks.get_network!(id)

    {:noreply,
     socket
     |> assign(:page_title, "Edit network")
     |> assign(:network, network)
     |> assign(:models, network.models)}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, push_patch(socket, to: Routes.network_edit_path(socket, :edit, socket.assigns.network))}
  end

  @impl true
  def handle_event("append_model", %{"value" => model}, socket) do
    {:ok, network} = Networks.append_model(socket.assigns.network, model)

    {:noreply, assign(socket, :models, network.models)}
  end

  @impl true
  def handle_event("remove_model", %{"pos" => pos}, socket) do
    {:ok, network} = Networks.remove_model(socket.assigns.network, String.to_integer(pos))

    {:noreply, assign(socket, :models, network.models)}
  end

  @impl true
  def handle_event("move_model_up", %{"pos" => pos}, socket) do
    initial_index = String.to_integer(pos)
    final_index = initial_index - 1
    {:ok, network} = Networks.reorder_models(socket.assigns.network, initial_index, final_index)

    {:noreply, assign(socket, :models, network.models)}
  end

  @impl true
  def handle_event("move_model_down", %{"pos" => pos}, socket) do
    initial_index = String.to_integer(pos)
    final_index = initial_index + 1
    {:ok, network} = Networks.reorder_models(socket.assigns.network, initial_index, final_index)

    {:noreply, assign(socket, :models, network.models)}
  end

  def models_dropdown(assigns) do
    ~H"""
    <.dropdown label="Add model">
      <%= for model <- Models.list_models() do %>
        <.dropdown_menu_item link_type="button" phx_click="append_model" value={model} label={String.split(model, "/") |> List.last} />
      <% end %>
    </.dropdown>
    """
  end
end
