defmodule PanicWeb.NetworkLive.Show do
  use PanicWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <%= @network.name %>
      <:subtitle><%= @network.description %></:subtitle>

      <:actions>
        <.link patch={~p"/networks/#{@network}/edit"} phx-click={JS.push_focus()}>
          <.button>Edit network</.button>
        </.link>
      </:actions>
    </.header>

    <.back navigate={~p"/"}>Back to networks</.back>

    <.modal
      :if={@live_action == :edit}
      id="network-modal"
      show
      on_cancel={JS.patch(~p"/networks/#{@network}")}
    >
      <.live_component
        module={PanicWeb.NetworkLive.FormComponent}
        id={@network.id}
        title={@page_title}
        current_user={@current_user}
        action={@live_action}
        network={@network}
        patch={~p"/networks/#{@network}"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"network_id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns[:live_action]))
     |> assign(:network, Ash.get!(Panic.Engine.Network, id, actor: socket.assigns[:current_user]))}
  end

  @impl true
  def handle_info({PanicWeb.NetworkLive.FormComponent, {:saved, network}}, socket) do
    {:noreply, assign(socket, network: network)}
  end

  defp page_title(:show), do: "Show Network"
  defp page_title(:edit), do: "Edit Network"
end
