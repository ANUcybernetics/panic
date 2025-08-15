defmodule PanicWeb.NetworkLive.Show do
  @moduledoc false
  use PanicWeb, :live_view

  import PanicWeb.PanicComponents

  alias PanicWeb.NetworkLive.ModelSelectComponent
  alias PanicWeb.WatcherSubscriber
  alias Phoenix.Socket.Broadcast

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      {@network.name}
    </.header>
    <section :if={@network.description} class="mt-16 prose prose-purple">
      {@network.description |> MDEx.to_html!() |> raw}
    </section>

    <section class="mt-16">
      <h2 class="font-semibold mb-8">
        Control panel
      </h2>
      <div class="flex space-x-4">
        <.link navigate={~p"/networks/#{@network}/edit"} phx-click={JS.push_focus()}>
          <.button>Edit network</.button>
        </.link>
        <.link patch={~p"/networks/#{@network}/info/qr"} type="button">
          <.button>QR code</.button>
        </.link>
        <.link href={~p"/networks/#{@network}/terminal"} type="button">
          <.button>Terminal</.button>
        </.link>
        <.link navigate={~p"/sign-out"} type="button">
          <.button>Sign out</.button>
        </.link>
        <.button class="ring-purple-300 ring-2" phx-click="stop">
          Stop
        </.button>
      </div>
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

    <section class="mt-16">
      <h2 class="font-semibold mb-8">Installations</h2>
      <div :if={@network.installations == []} class="text-gray-500 italic">
        No installations yet.
        <.link
          navigate={~p"/installations/new"}
          class="text-purple-600 hover:text-purple-800 underline"
        >
          Create one
        </.link>
      </div>
      <.table
        :if={@network.installations != []}
        id="network-installations"
        rows={@streams.installations}
        row_click={fn {_id, installation} -> JS.navigate(~p"/installations/#{installation}") end}
      >
        <:col :let={{_id, installation}} label="Name">{installation.name}</:col>
        <:col :let={{_id, installation}} label="Watchers">
          {length(installation.watchers)}
        </:col>
        <:action :let={{_id, installation}}>
          <div class="sr-only">
            <.link navigate={~p"/installations/#{installation}"}>Show</.link>
          </div>
          <.link navigate={~p"/installations/#{installation}/edit"}>Edit</.link>
        </:action>
      </.table>
    </section>

    <section class="mt-16">
      <h2 class="font-semibold mb-8">Terminal</h2>
      <.live_component
        module={PanicWeb.NetworkLive.TerminalComponent}
        network={@network}
        genesis_invocation={@genesis_invocation}
        current_user={@current_user}
        lockout_seconds_remaining={@lockout_seconds_remaining}
        id={@network.id}
      />
    </section>

    <section class="mt-8">
      <.live_component
        module={PanicWeb.NetworkLive.RunnerStatusComponent}
        id="runner-status"
        network_id={@network.id}
        genesis_invocation={@genesis_invocation}
        invocations={@streams.invocations}
        lockout_seconds_remaining={@lockout_seconds_remaining}
      />
    </section>

    <section class="mt-16">
      <h2 class="font-semibold mb-8">
        Last prompt <span :if={@genesis_invocation}>: {@genesis_invocation.input}</span>
      </h2>

      <.display invocations={@streams.invocations} display={@display} />
    </section>

    <.back href={~p"/users/#{@current_user}/"}>Back to networks</.back>
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
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"network_id" => network_id}, _session, socket) do
    case Ash.get(Panic.Engine.Network, network_id,
           actor: socket.assigns.current_user,
           load: [:installations]
         ) do
      {:ok, network} ->
        {:noreply,
         socket
         |> assign(:page_title, page_title(socket.assigns[:live_action]))
         |> assign(:network, network)
         |> stream(:installations, network.installations)
         |> WatcherSubscriber.configure_invocation_stream(network, {:grid, 2, 3})}

      {:error, _error} ->
        {:noreply, push_navigate(socket, to: ~p"/404")}
    end
  end

  @impl true
  def handle_info({PanicWeb.NetworkLive.FormComponent, {:saved, network}}, socket) do
    {:noreply, assign(socket, network: network)}
  end

  @impl true
  def handle_info({ModelSelectComponent, {:models_updated, network}}, socket) do
    {:noreply, assign(socket, network: network)}
  end

  @impl true
  def handle_info({PanicWeb.NetworkLive.TerminalComponent, {:genesis_invocation, genesis_invocation}}, socket) do
    {:noreply, assign(socket, :genesis_invocation, genesis_invocation)}
  end

  @impl true
  def handle_info(%Broadcast{topic: "invocation:" <> _, event: "runner_state_changed"} = _message, socket) do
    # When runner state changes, update the component to get new timing info
    send_update(PanicWeb.NetworkLive.RunnerStatusComponent,
      id: "runner-status",
      network_id: socket.assigns.network.id,
      genesis_invocation: socket.assigns[:genesis_invocation],
      invocations: socket.assigns.streams.invocations,
      lockout_seconds_remaining: socket.assigns[:lockout_seconds_remaining]
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info(%Broadcast{topic: "invocation:" <> _} = message, socket) do
    WatcherSubscriber.handle_invocation_message(message, socket)
  end

  @impl true
  def handle_event("stop", _params, socket) do
    Panic.Engine.NetworkRunner.stop_run(socket.assigns.network.id)
    {:noreply, socket}
  end

  defp page_title(:show), do: "Show Network"
  defp page_title(:edit), do: "Edit Network"
end
