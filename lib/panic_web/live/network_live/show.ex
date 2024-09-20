defmodule PanicWeb.NetworkLive.Show do
  @moduledoc false
  use PanicWeb, :live_view
  use PanicWeb.InvocationWatcher, watcher: {:grid, 2, 3}

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <%= @network.name %>

      <:actions>
        <.link patch={~p"/networks/#{@network}/edit"} phx-click={JS.push_focus()}>
          <.button>Edit network</.button>
        </.link>
      </:actions>
    </.header>

    <section class="mt-16">
      <p><%= @network.description %></p>
    </section>

    <section class="mt-16">
      <h2 class="font-semibold">Models</h2>

      <.live_component
        module={PanicWeb.NetworkLive.ModelSelectComponent}
        id="model-select"
        network={@network}
        current_user={@current_user}
      />
    </section>

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
  def handle_params(%{"network_id" => network_id}, _session, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns[:live_action]))
     |> subscribe_to_network(network_id, socket.assigns.current_user)}
  end

  @impl true
  def handle_info({PanicWeb.NetworkLive.FormComponent, {:saved, network}}, socket) do
    {:noreply, assign(socket, network: network)}
  end

  @impl true
  def handle_info({PanicWeb.NetworkLive.ModelSelectComponent, {:models_updated, network}}, socket) do
    {:noreply, assign(socket, network: network)}
  end

  defp page_title(:show), do: "Show Network"
  defp page_title(:edit), do: "Edit Network"
end
