defmodule PanicWeb.NetworkLive.Show do
  use PanicWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Network <%= @network.id %>
      <:subtitle>This is a network record from your database.</:subtitle>

      <:actions>
        <.link patch={~p"/networks/#{@network}/edit"} phx-click={JS.push_focus()}>
          <.button>Edit network</.button>
        </.link>
      </:actions>
    </.header>

    <.list>
      <:item title="Id"><%= @network.id %></:item>
    </.list>

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
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:network, Ash.get!(Panic.Engine.Network, id))}
  end

  defp page_title(:show), do: "Show Network"
  defp page_title(:edit), do: "Edit Network"
end
