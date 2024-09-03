defmodule PanicWeb.NetworkLive.Show do
  use PanicWeb, :live_view

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
      <div class="mt-8">
        State:
        <span class={[
          "rounded-lg px-2 py-2 font-semibold",
          @network.state == :stopped && "bg-red-100 text-red-800",
          @network.state != :stopped && "bg-green-100 text-green-800"
        ]}>
          <%= @network.state %>
        </span>
      </div>
    </section>

    <section class="mt-16">
      <h2 class="font-semibold">Models</h2>

      <.live_component
        module={PanicWeb.NetworkLive.ModelSelectComponent}
        id="model-select"
        network={@network}
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
