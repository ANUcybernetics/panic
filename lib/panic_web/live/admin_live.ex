defmodule PanicWeb.AdminLive do
  @moduledoc false
  use PanicWeb, :live_view

  alias PanicWeb.NetworkLive.NetworkHelpers
  alias Phoenix.Socket.Broadcast

  @invocation_stream_limit 100

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Admin panel
      <:actions>
        <.link href={~p"/admin/backup"} download>
          <.button>
            Download backup
          </.button>
        </.link>
        <.button
          phx-click="stop_all_jobs"
          data-confirm="Are you sure you want to stop all running jobs?"
        >
          Stop all jobs
        </.button>
      </:actions>
    </.header>

    <section class="mt-16">
      <h2 class="text-xl font-semibold">API keys</h2>
      <p class="mt-2 text-sm">
        Keys for the JSON API at <code>/api</code>
        (<.link href={~p"/api/swaggerui"} class="underline">docs</.link>), sent as <code>Authorization: Bearer &lt;key&gt;</code>. They act as you, and stop working if you stop being an admin.
      </p>

      <div :if={@new_api_key} id="new-api-key" class="mt-4">
        <p>Copy this key now: it won't be shown again.</p>
        <code class="mt-2 block break-all select-all">{@new_api_key}</code>
      </div>

      <.simple_form for={@api_key_form} id="api-key-form" phx-submit="create_api_key">
        <.input field={@api_key_form[:name]} label="Name" required />
        <.input
          field={@api_key_form[:expires_in]}
          type="select"
          label="Expires"
          options={[{"Never", "never"}, {"In 30 days", "30"}, {"In a year", "365"}]}
        />
        <:actions>
          <.button>Create API key</.button>
        </:actions>
      </.simple_form>

      <.table :if={@api_keys != []} id="api-key-table" rows={@api_keys} row_id={&"api-key-#{&1.id}"}>
        <:col :let={api_key} label="Name">{api_key.name}</:col>
        <:col :let={api_key} label="Created">
          {Calendar.strftime(api_key.inserted_at, "%Y-%m-%d")}
        </:col>
        <:col :let={api_key} label="Expires">
          {if api_key.expires_at, do: Calendar.strftime(api_key.expires_at, "%Y-%m-%d"), else: "never"}
        </:col>
        <:action :let={api_key}>
          <.button
            phx-click="revoke_api_key"
            phx-value-id={api_key.id}
            data-confirm={"Revoke #{api_key.name}? Anything using it will stop working."}
          >
            Revoke
          </.button>
        </:action>
      </.table>
    </section>

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
    networks = Panic.Engine.list_networks!(authorize?: false)

    if connected?(socket) do
      # admin view subscribes to _all_ invocations
      Enum.each(networks, fn network ->
        PanicWeb.Endpoint.subscribe("invocation:#{network.id}")
      end)
    end

    {:ok,
     socket
     |> assign(networks: networks, new_api_key: nil)
     |> assign_api_keys()
     |> stream(:invocations, [])}
  end

  @impl true
  def handle_info(%Broadcast{topic: "invocation:" <> _, event: "presence_diff"}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(%Broadcast{topic: "invocation:" <> _} = message, socket) do
    case message.payload do
      %{data: invocation} ->
        {:noreply, stream_insert(socket, :invocations, invocation, at: 0, limit: @invocation_stream_limit)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("stop_all_jobs", _params, socket) do
    stopped_count =
      [authorize?: false]
      |> Panic.Engine.list_running_networks!()
      |> Enum.map(&Panic.Engine.stop_run!(&1, authorize?: false))
      |> length()

    message =
      case stopped_count do
        0 -> "No running jobs found to stop"
        1 -> "Stopped 1 running job"
        n -> "Stopped #{n} running jobs"
      end

    {:noreply, put_flash(socket, :info, message)}
  end

  @impl true
  def handle_event("create_api_key", %{"api_key" => params}, socket) do
    actor = socket.assigns.current_user

    case Panic.Accounts.create_api_key(
           params["name"],
           %{expires_at: expires_at(params["expires_in"])},
           actor: actor
         ) do
      {:ok, api_key} ->
        {:noreply,
         socket
         |> assign(new_api_key: api_key.__metadata__.plaintext_api_key)
         |> assign_api_keys()}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Couldn't create the API key: give it a name")}
    end
  end

  @impl true
  def handle_event("revoke_api_key", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    api_key = Enum.find(socket.assigns.api_keys, &(&1.id == id))
    :ok = Panic.Accounts.destroy_api_key(api_key, actor: actor)

    {:noreply,
     socket
     |> assign(new_api_key: nil)
     |> assign_api_keys()
     |> put_flash(:info, "Revoked #{api_key.name}")}
  end

  defp assign_api_keys(socket) do
    api_keys =
      Panic.Accounts.list_api_keys!(
        actor: socket.assigns.current_user,
        query: [sort: [inserted_at: :desc]]
      )

    assign(socket,
      api_keys: api_keys,
      api_key_form: to_form(%{"name" => "", "expires_in" => "never"}, as: :api_key)
    )
  end

  defp expires_at("30"), do: DateTime.shift(DateTime.utc_now(), day: 30)
  defp expires_at("365"), do: DateTime.shift(DateTime.utc_now(), day: 365)
  defp expires_at(_never), do: nil

  defp invocation_io_link(%{type: :input} = assigns) do
    model = NetworkHelpers.get_model_or_placeholder(assigns.invocation.model)
    assigns = assign(assigns, :model, model)

    ~H"""
    <%= case @model.input_type do %>
      <% :text -> %>
        {@invocation.input}
      <% :unknown -> %>
        <span class="text-gray-500 italic">Unknown model type</span>
      <% _ -> %>
        <.link href={@invocation.input}>external link</.link>
    <% end %>
    """
  end

  defp invocation_io_link(%{type: :output} = assigns) do
    model = NetworkHelpers.get_model_or_placeholder(assigns.invocation.model)
    assigns = assign(assigns, :model, model)

    ~H"""
    <%= case @model.output_type do %>
      <% :text -> %>
        {@invocation.output}
      <% :unknown -> %>
        <span class="text-gray-500 italic">Unknown model type</span>
      <% _ -> %>
        <.link href={@invocation.output}>external link</.link>
    <% end %>
    """
  end
end
