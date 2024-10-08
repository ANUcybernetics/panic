defmodule PanicWeb.NetworkLive.Show do
  @moduledoc false
  use PanicWeb, :live_view
  use PanicWeb.DisplayStreamer

  import PanicWeb.PanicComponents

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <%= @network.name %>

      <:actions>
        <.link navigate={~p"/networks/#{@network}/edit"} phx-click={JS.push_focus()}>
          <.button>Edit network</.button>
        </.link>
      </:actions>
    </.header>

    <section class="mt-16">
      <p><%= @network.description %></p>
    </section>

    <section class="mt-16">
      <h2 class="font-semibold mb-8">Models</h2>

      <.live_component
        module={PanicWeb.NetworkLive.ModelSelectComponent}
        id="model-select"
        network={@network}
        current_user={@current_user}
      />
    </section>

    <section>
      <.live_component
        module={PanicWeb.NetworkLive.TerminalComponent}
        network={@network}
        genesis_invocation={@genesis_invocation}
        current_user={@current_user}
        id={@network.id}
      />

      <.button phx-click="stop" class="mt-4">
        Stop
      </.button>
    </section>

    <section class="mt-16">
      <h2 class="font-semibold mb-8">
        Current run <span :if={@genesis_invocation}>: <%= @genesis_invocation.input %></span>
      </h2>

      <.display invocations={@streams.invocations} display={@display} />
    </section>

    <.back navigate={~p"/users/#{@current_user}/"}>Back to networks</.back>

    <.modal
      :if={@live_action == :edit}
      id="network-modal"
      show
      on_cancel={JS.navigate(~p"/networks/#{@network}")}
    >
      <.live_component
        module={PanicWeb.NetworkLive.FormComponent}
        id={@network.id}
        title={@page_title}
        current_user={@current_user}
        action={@live_action}
        network={@network}
        navigate={~p"/networks/#{@network}"}
      />
    </.modal>
    """
  end

  @impl true
  def handle_params(%{"network_id" => network_id}, _session, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns[:live_action]))
     |> configure_display_stream(network_id, {:grid, 2, 3})}
  end

  @impl true
  def handle_info({PanicWeb.NetworkLive.FormComponent, {:saved, network}}, socket) do
    {:noreply, assign(socket, network: network)}
  end

  @impl true
  def handle_info({PanicWeb.NetworkLive.ModelSelectComponent, {:models_updated, network}}, socket) do
    {:noreply, assign(socket, network: network)}
  end

  @impl true
  def handle_event("stop", _params, socket) do
    Panic.Workers.Invoker.cancel_running_jobs(socket.assigns.network.id)
    {:noreply, socket}
  end

  defp page_title(:show), do: "Show Network"
  defp page_title(:edit), do: "Edit Network"
end
