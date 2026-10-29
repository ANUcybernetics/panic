defmodule PanicWeb.AdminLive do
  @moduledoc false
  use PanicWeb, :live_view

  alias Panic.Accounts.PlatformCredentials
  alias PanicWeb.NetworkLive.NetworkHelpers
  alias Phoenix.Socket.Broadcast

  @invocation_stream_limit 100

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Admin panel
      <:actions>
        <.button href={~p"/admin/backup"} download>
          <.icon name="hero-arrow-down-tray" /> Download backup
        </.button>
        <.button
          phx-click="stop_all_jobs"
          data-confirm="Are you sure you want to stop all running jobs?"
          variant="error"
        >
          Stop all jobs
        </.button>
      </:actions>
    </.header>

    <section class="mt-12">
      <h2 class="text-lg font-semibold text-primary-content">Platform keys</h2>
      <p class="mt-2 text-sm text-base-content/70">
        The keys every run spends, whoever starts it. They're stored encrypted and never sent back
        to the browser: leave a field blank to keep its key, or paste a new one to replace it.
      </p>

      <.form
        for={@credentials_form}
        id="credentials-form"
        class="mt-4"
        phx-change="validate_credentials"
        phx-submit="save_credentials"
      >
        <div class="grid gap-x-4 sm:grid-cols-2">
          <.input
            :for={key <- PlatformCredentials.keys()}
            field={@credentials_form[key]}
            type="password"
            value=""
            autocomplete="off"
            label={credential_label(key)}
          >
            <:help>
              <span id={"#{key}-status"}>{credential_status(Map.get(@credentials, key))}</span>
            </:help>
          </.input>
        </div>
        <div class="mt-6 flex flex-wrap gap-2">
          <.button variant="primary" phx-disable-with="Saving...">Save keys</.button>
        </div>
      </.form>
    </section>

    <section class="mt-12">
      <h2 class="text-lg font-semibold text-primary-content">JSON API keys</h2>
      <p class="mt-2 text-sm text-base-content/70">
        Keys for the JSON API at <code>/api</code>
        (<.link href={~p"/api/swaggerui"} class="underline">docs</.link>), sent as <code>Authorization: Bearer &lt;key&gt;</code>. They act as you, and stop working if you stop being an admin.
      </p>

      <div
        :if={@new_api_key}
        id="new-api-key"
        role="alert"
        class="alert alert-success alert-soft mt-4 block"
      >
        <p>Copy this key now: it won't be shown again.</p>
        <code class="mt-2 block break-all select-all">{@new_api_key}</code>
      </div>

      <.form for={@api_key_form} id="api-key-form" phx-submit="create_api_key" class="mt-4 mb-6">
        <div class="grid gap-x-4 sm:grid-cols-2">
          <.input field={@api_key_form[:name]} label="Name" required />
          <.input
            field={@api_key_form[:expires_in]}
            type="select"
            label="Expires"
            options={[{"Never", "never"}, {"In 30 days", "30"}, {"In a year", "365"}]}
          />
        </div>
        <div class="mt-6 flex flex-wrap gap-2">
          <.button>Create API key</.button>
        </div>
      </.form>

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
            variant="error"
            size="sm"
          >
            Revoke
          </.button>
        </:action>
      </.table>
    </section>

    <section class="mt-12">
      <h2 class="mb-4 text-lg font-semibold text-primary-content">Invocations</h2>

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
          <span class="line-clamp-2 break-all">
            <.invocation_io_link invocation={invocation} type={:input} />
          </span>
        </:col>
        <:col :let={{_id, invocation}} label="Output">
          <span class="line-clamp-2 break-all">
            <.invocation_io_link invocation={invocation} type={:output} />
          </span>
        </:col>
      </.table>
    </section>

    <section class="mt-12">
      <h2 class="mb-4 text-lg font-semibold text-primary-content">Networks</h2>

      <.table :if={@networks != []} id="network-table" rows={@networks}>
        <:col :let={network} label="Name">
          <.link navigate={~p"/networks/#{network}"} class="font-semibold">
            {network.name}
          </.link>
        </:col>
        <:col :let={network} label="User ID">{network.user_id}</:col>
        <:col :let={network} label="Description" class="hidden sm:table-cell">
          <span class="line-clamp-2">{network.description}</span>
        </:col>
      </.table>
      <p :if={@networks == []} class="text-base-content/70">No networks found.</p>
    </section>

    <section class="mt-12">
      <h2 class="mb-4 text-lg font-semibold text-primary-content">Users</h2>
      <.table id="user-table" rows={@users} row_id={&"user-#{&1.id}"}>
        <:col :let={user} label="ID">{user.id}</:col>
        <:col :let={user} label="Email">{user.email}</:col>
        <:col :let={user} label="Admin">{if user.admin, do: "yes", else: "no"}</:col>
      </.table>
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
     |> assign(
       networks: networks,
       users: Panic.Accounts.list_users!(authorize?: false),
       new_api_key: nil
     )
     |> assign_credentials()
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
  def handle_event("validate_credentials", %{"form" => params}, socket) do
    {:noreply,
     assign(socket,
       credentials_form: AshPhoenix.Form.validate(socket.assigns.credentials_form, params)
     )}
  end

  def handle_event("save_credentials", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.credentials_form, params: params) do
      {:ok, _credentials} ->
        {:noreply, socket |> assign_credentials() |> put_flash(:info, "Platform keys saved")}

      {:error, form} ->
        {:noreply, assign(socket, credentials_form: form)}
    end
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

  defp assign_credentials(socket) do
    actor = socket.assigns.current_user

    credentials =
      Panic.Accounts.get_platform_credentials!(actor: actor, load: PlatformCredentials.keys())

    assign(socket,
      credentials: credentials,
      credentials_form: to_form(Panic.Accounts.form_to_update_platform_credentials(credentials, actor: actor))
    )
  end

  defp credential_label(key) do
    case PlatformCredentials.platform(key) do
      nil ->
        key
        |> Atom.to_string()
        |> String.replace_suffix("_token", "")
        |> String.replace("_", " ")
        |> String.capitalize()

      platform ->
        PlatformCredentials.platform_name(platform)
    end
  end

  # enough to tell keys apart without revealing them
  defp credential_status(nil), do: "Not set"
  defp credential_status(key), do: "Set, ending in #{String.slice(key, -4..-1//1)}"

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

  defp invocation_io_link(assigns) do
    model = NetworkHelpers.get_model_or_placeholder(assigns.invocation.model)

    {io_type, value} =
      case assigns.type do
        :input -> {model.input_type, assigns.invocation.input}
        :output -> {model.output_type, assigns.invocation.output}
      end

    assigns = assign(assigns, io_type: io_type, value: value)

    ~H"""
    <%= case @io_type do %>
      <% :text -> %>
        {@value}
      <% :unknown -> %>
        <span class="italic text-base-content/60">Unknown model type</span>
      <% _ -> %>
        <.link href={@value} class="link">external link</.link>
    <% end %>
    """
  end
end
