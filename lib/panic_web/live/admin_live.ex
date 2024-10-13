defmodule PanicWeb.AdminLive do
  @moduledoc false
  use PanicWeb, :live_view

  import Ecto.Query

  @invocation_stream_limit 100

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Admin panel
    </.header>

    <section class="mt-16">
      <h2 class="text-xl font-semibold">Invocations</h2>

      <.table id="all-invocation-table" rows={@streams.invocations}>
        <:col :let={{_id, invocation}} label="ID">
          <.link patch={~p"/display/static/#{invocation.id}"} phx-click={JS.push_focus()}>
            <%= invocation.id %>
          </.link>
        </:col>
        <:col :let={{_id, invocation}} label="Numbers">
          <%= "#{invocation.network_id}-#{invocation.run_number}-#{invocation.sequence_number}" %>
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
      <h2 class="text-xl font-semibold">Oban Errors</h2>

      <%= if @oban_jobs != [] do %>
        <.table id="oban-job-table" rows={@oban_jobs}>
          <:col :let={job} label="ID"><%= job.id %></:col>
          <:col :let={job} label="Worker"><%= job.worker %></:col>
          <:col :let={job} label="State"><%= job.state %></:col>
          <:col :let={job} label="Last error">
            <%= job.errors |> List.last() |> Map.get(:error) %>
          </:col>
        </.table>
      <% else %>
        <p class="mt-8">No Oban jobs with errors.</p>
      <% end %>
    </section>

    <section class="mt-16">
      <h2 class="text-xl font-semibold">Networks</h2>

      <%= if @networks != [] do %>
        <.table id="network-table" rows={@networks}>
          <:col :let={network} label="Name">
            <.link patch={~p"/networks/#{network}/"} phx-click={JS.push_focus()}>
              <%= network.name %>
            </.link>
          </:col>
          <:col :let={network} label="User ID"><%= network.user_id %></:col>
          <:col :let={network} label="Description"><%= network.description %></:col>
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
    oban_jobs = get_oban_jobs_with_errors()

    if connected?(socket) do
      # admin view subscribes to _all_ invocations
      Enum.each(networks, fn network ->
        PanicWeb.Endpoint.subscribe("invocation:#{network.id}")
      end)

      :timer.send_interval(:timer.seconds(30), :update_oban_jobs)
    end

    {:ok,
     socket
     |> assign(networks: networks, oban_jobs: oban_jobs)
     |> stream(:invocations, [])}
  end

  @impl true
  def handle_info(:update_oban_jobs, socket) do
    {:noreply, assign(socket, oban_jobs: get_oban_jobs_with_errors())}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "invocation:" <> _} = message, socket) do
    invocation = message.payload.data
    dbg()
    {:noreply, stream_insert(socket, :invocations, invocation, at: 0, limit: @invocation_stream_limit)}
  end

  defp invocation_io_link(%{type: :input} = assigns) do
    ~H"""
    <%= case @invocation.model |> List.last |> Panic.Model.by_id!() |> Map.fetch!(:input_type) do %>
      <% :text -> %>
        <%= @invocation.input %>
      <% _ -> %>
        <.link href={@invocation.input}>external link</.link>
    <% end %>
    """
  end

  defp invocation_io_link(%{type: :output} = assigns) do
    ~H"""
    <%= case @invocation.model |> List.last |> Panic.Model.by_id!() |> Map.fetch!(:output_type) do %>
      <% :text -> %>
        <%= @invocation.output %>
      <% _ -> %>
        <.link href={@invocation.output}>external link</.link>
    <% end %>
    """
  end

  defp get_oban_jobs_with_errors do
    Panic.Repo.all(where(Oban.Job, [j], j.errors != []))
  end
end
