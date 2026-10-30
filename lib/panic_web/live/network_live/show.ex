defmodule PanicWeb.NetworkLive.Show do
  @moduledoc false
  use PanicWeb, :live_view

  import PanicWeb.PanicComponents

  alias Panic.Accounts.PlatformCredentials
  alias PanicWeb.NetworkLive.ModelSelectComponent
  alias PanicWeb.NetworkLive.RunnerStatusComponent
  alias PanicWeb.RunFormat
  alias PanicWeb.WatcherSubscriber

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        {@network.name}
        <:subtitle>
          Lockout: {RunFormat.duration(@network.lockout_seconds)} · Anonymous terminal: {if @network.anon_terminal_minutes,
            do: RunFormat.duration(@network.anon_terminal_minutes * 60, :minute),
            else: "off"}
        </:subtitle>
        <:actions>
          <.button patch={~p"/networks/#{@network}/edit"}>Edit</.button>
          <.button :if={@network.anon_terminal_minutes} navigate={~p"/networks/#{@network}/info/qr"}>
            QR
          </.button>
          <.button href={~p"/networks/#{@network}/terminal"}>Terminal</.button>
          <.button phx-click="stop" variant="error">Stop</.button>
        </:actions>
      </.header>

      <section :if={@network.description} class="prose prose-purple max-w-none">
        {@network.description |> MDEx.to_html!() |> raw}
      </section>

      <div :if={@missing_keys != []} id="missing-keys" role="alert" class="alert alert-warning mt-6">
        <.icon name="hero-exclamation-triangle" class="size-5" />
        <span>
          No API key set for {Enum.map_join(@missing_keys, ", ", &PlatformCredentials.platform_name/1)}, so runs won't start.
          <.link :if={@current_user.admin} navigate={~p"/admin"} class="underline">Add keys</.link>
          <span :if={!@current_user.admin}>Ask an admin to add them.</span>
        </span>
      </div>

      <section class="mt-12">
        <.section_header>Models</.section_header>
        <.live_component
          module={PanicWeb.NetworkLive.ModelSelectComponent}
          id="model-select"
          network={@network}
          current_user={@current_user}
        />
      </section>

      <section class="mt-12">
        <.section_header>Run</.section_header>
        <.live_component
          module={PanicWeb.NetworkLive.TerminalComponent}
          network={@network}
          genesis_invocation={@genesis_invocation}
          current_user={@current_user}
          id={@network.id}
        />
        <RunnerStatusComponent.runner_status
          id="runner-status"
          network={@network}
          genesis_invocation={@genesis_invocation}
          current_invocation={@current_invocation}
        />
        <p class="mt-6 mb-4 break-words">
          <span class="text-base-content/60">Initial prompt:</span>
          <span :if={@genesis_invocation}>{@genesis_invocation.input}</span>
        </p>
        <.display
          invocations={@streams.invocations}
          display={@display}
          latest_sequence={@latest_sequence}
        />
      </section>

      <section class="mt-12">
        <.section_header>
          Installations
          <:actions>
            <.button navigate={~p"/installations/new"} size="sm">
              <.icon name="hero-plus" /> New installation
            </.button>
          </:actions>
        </.section_header>
        <p :if={@network.installations == []} class="text-base-content/70">
          No installations yet.
        </p>
        <.table
          :if={@network.installations != []}
          id="network-installations"
          rows={@streams.installations}
          row_click={fn {_id, installation} -> JS.navigate(~p"/installations/#{installation}") end}
        >
          <:col :let={{_id, installation}} label="Name">
            <.link navigate={~p"/installations/#{installation}"} class="font-semibold">
              {installation.name}
            </.link>
          </:col>
          <:col :let={{_id, installation}} label="Watchers">
            {length(installation.watchers)}
          </:col>
        </.table>
      </section>

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
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"network_id" => network_id}, _session, socket) do
    case Panic.Engine.get_network(network_id,
           actor: socket.assigns.current_user,
           load: [:installations, :user]
         ) do
      {:ok, network} ->
        socket =
          socket
          |> assign(:page_title, page_title(socket.assigns[:live_action]))
          |> assign_network(network)
          |> stream(:installations, network.installations)
          |> assign(:current_invocation, current_run_head(network))
          |> WatcherSubscriber.configure_invocation_stream(network, {:grid, 2, 3})

        {:noreply, socket}

      {:error, _error} ->
        {:noreply, push_navigate(socket, to: ~p"/404")}
    end
  end

  defp assign_network(socket, network) do
    assign(socket, network: network, missing_keys: PlatformCredentials.missing(network.models))
  end

  defp current_run_head(%{current_run_number: nil}), do: nil

  defp current_run_head(network) do
    case Panic.Engine.current_run_head(network.current_run_number, authorize?: false) do
      {:ok, invocation} -> invocation
      {:error, _} -> nil
    end
  end

  @impl true
  def handle_info({PanicWeb.NetworkLive.FormComponent, {:saved, network}}, socket) do
    {:noreply, assign_network(socket, network)}
  end

  @impl true
  def handle_info({ModelSelectComponent, {:models_updated, network}}, socket) do
    {:noreply, assign_network(socket, network)}
  end

  @impl true
  def handle_info({PanicWeb.NetworkLive.TerminalComponent, {:genesis_invocation, genesis_invocation}}, socket) do
    {:noreply, assign(socket, :genesis_invocation, genesis_invocation)}
  end

  @impl true
  def handle_event("stop", _params, socket) do
    # the network broadcast updates the run state of every viewer, this one included
    Panic.Engine.stop_run!(socket.assigns.network, actor: socket.assigns.current_user)
    {:noreply, socket}
  end

  defp page_title(:show), do: "Show Network"
  defp page_title(:edit), do: "Edit Network"
end
