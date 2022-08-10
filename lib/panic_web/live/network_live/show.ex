defmodule PanicWeb.NetworkLive.Show do
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
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:network, network)
     |> assign(:models, network.models)}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, push_patch(socket, to: Routes.network_show_path(socket, :show, socket.assigns.network))}
  end

  @impl true
  def handle_event("add_model", %{"value" => model}, socket) do
    {:ok, network} = Networks.append_model(socket.assigns.network, model)

    {:noreply, assign(socket, :models, network.models)}
  end

  def models_dropdown(assigns) do
    ~H"""
    <.dropdown label="Add model">
      <%= for model <- Models.list_models() do %>
        <.dropdown_menu_item link_type="button" phx_click="add_model" value={model} label={String.split(model, "/") |> List.last} />
      <% end %>
    </.dropdown>
    """
  end

  defp page_title(:show), do: "Show Network"
  defp page_title(:edit), do: "Edit Network"
end
