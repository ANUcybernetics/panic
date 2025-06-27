defmodule PanicWeb.AdminLive do
  @moduledoc false
  use PanicWeb, :live_view

  alias Phoenix.Socket.Broadcast

  @invocation_stream_limit 100

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Admin panel
      <:actions>
        <.button
          phx-click="stop_all_jobs"
          data-confirm="Are you sure you want to stop all running jobs?"
        >
          Stop all jobs
        </.button>
      </:actions>
    </.header>

    <section class="mt-16">
      <h2 class="text-xl font-semibold">Invocations</h2>

      <.table id="all-invocation-table" rows={@streams.invocations}>
        <:col :let={{_id, invocation}} label="ID">
          <.link patch={~p"/display/static/#{invocation.id}"} phx-click={JS.push_focus()}>
            {invocation.id}
          </.link>
        </:col>
        <:col :let={{_id, invocation}} label="Numbers">
          {"#{invocation.network_id}-#{invocation.run_number}-#{invocation.sequence_number}"}
        </:col>
        <:col :let={{_id, invocation}} label="Input">
          <.invocation_io_link invocation={invocation} type={:input} />
        </:col>
        <:col :let={{_id, invocation}} label="Output">
          <.invocation_io_link invocation={invocation} type={:output} />
        </:col>
      </.table>
    </section>

    <section class="mt-16">
      <h2 class="text-xl font-semibold">Networks</h2>

      <%= if @networks != [] do %>
        <.table id="network-table" rows={@networks}>
          <:col :let={network} label="Name">
            <.link href={~p"/networks/#{network}/"} phx-click={JS.push_focus()}>
              {network.name}
            </.link>
          </:col>
          <:col :let={network} label="User ID">{network.user_id}</:col>
          <:col :let={network} label="Description">{network.description}</:col>
        </.table>
      <% else %>
        <p class="mt-8">No networks found.</p>
      <% end %>
    </section>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    networks = Ash.read!(Panic.Engine.Network, authorize?: false)

    if connected?(socket) do
      # admin view subscribes to _all_ invocations
      Enum.each(networks, fn network ->
        PanicWeb.Endpoint.subscribe("invocation:#{network.id}")
      end)
    end

    {:ok,
     socket
     |> assign(networks: networks)
     |> stream(:invocations, [])}
  end

  @impl true
  def handle_info(%Broadcast{topic: "invocation:" <> _, event: "lockout_countdown"} = _message, socket) do
    # Ignore lockout countdown messages in admin view
    {:noreply, socket}
  end

  @impl true
  def handle_info(%Broadcast{topic: "invocation:" <> _} = message, socket) do
    invocation = message.payload.data

    {:noreply, stream_insert(socket, :invocations, invocation, at: 0, limit: @invocation_stream_limit)}
  end

  @impl true
  def handle_event("stop_all_jobs", _params, socket) do
    # Get all running NetworkRunner processes from the registry
    registry_entries = Registry.select(Panic.Engine.NetworkRegistry, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}])

    # Stop each NetworkRunner
    stopped_count =
      registry_entries
      |> Enum.map(fn {_network_id, pid} ->
        if Process.alive?(pid) do
          DynamicSupervisor.terminate_child(Panic.Engine.NetworkSupervisor, pid)
          1
        else
          0
        end
      end)
      |> Enum.sum()

    message =
      case stopped_count do
        0 -> "No running jobs found to stop"
        1 -> "Stopped 1 running job"
        n -> "Stopped #{n} running jobs"
      end

    {:noreply, put_flash(socket, :info, message)}
  end

  defp invocation_io_link(%{type: :input} = assigns) do
    ~H"""
    <%= case Panic.Model.by_id!(@invocation.model) |> Map.fetch!(:input_type) do %>
      <% :text -> %>
        {@invocation.input}
      <% _ -> %>
        <.link href={@invocation.input}>external link</.link>
    <% end %>
    """
  end

  defp invocation_io_link(%{type: :output} = assigns) do
    ~H"""
    <%= case Panic.Model.by_id!(@invocation.model) |> Map.fetch!(:output_type) do %>
      <% :text -> %>
        {@invocation.output}
      <% _ -> %>
        <.link href={@invocation.output}>external link</.link>
    <% end %>
    """
  end
end
