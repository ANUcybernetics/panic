defmodule PanicWeb.UserLive.Show do
  @moduledoc false
  use PanicWeb, :live_view

  alias Panic.Engine.Network

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      User email: {@user.email}
    </.header>

    <section>
      <div class="flex justify-between items-center mt-16">
        <h2 class="font-semibold">Networks</h2>
        <.link patch={~p"/users/#{@user}/new-network"} phx-click={JS.push_focus()}>
          <.button>Add network</.button>
        </.link>
      </div>

      <%= if @networks != [] do %>
        <.table id="network-list" rows={@networks}>
          <:col :let={network} label="Name">
            <.link href={~p"/networks/#{network}/"} phx-click={JS.push_focus()}>
              {network.name}
            </.link>
          </:col>
          <:col :let={network} label="Length">{length(network.models)}</:col>
          <:col :let={network} label="Description">{network.description}</:col>
          <:action :let={network}>
            <.link
              phx-click={JS.push("delete_network", value: %{id: network.id})}
              data-confirm="Are you sure you want to delete this network?"
              class="text-red-600 hover:text-red-900"
            >
              Delete
            </.link>
          </:action>
        </.table>
      <% else %>
        <p class="mt-8">User has no networks.</p>
      <% end %>
    </section>

    <section>
      <div class="flex justify-between items-center mt-16">
        <h2 class="font-semibold">API Tokens</h2>
        <.link navigate={~p"/api_tokens"} phx-click={JS.push_focus()}>
          <.button>Manage API Tokens</.button>
        </.link>
      </div>

      <%= if @api_tokens != [] do %>
        <.table id="api-token-list" rows={@api_tokens}>
          <:col :let={token} label="Name">
            <.link href={~p"/api_tokens/#{token}"} phx-click={JS.push_focus()}>
              {token.name}
            </.link>
          </:col>
          <:col :let={token} label="Platforms">
            <div class="flex gap-2">
              <span
                :if={token.openai_token}
                class="inline-flex items-center rounded-md bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20"
              >
                OpenAI
              </span>
              <span
                :if={token.replicate_token}
                class="inline-flex items-center rounded-md bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20"
              >
                Replicate
              </span>
              <span
                :if={token.gemini_token}
                class="inline-flex items-center rounded-md bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20"
              >
                Gemini
              </span>
            </div>
          </:col>
        </.table>
      <% else %>
        <p class="mt-8">
          No API tokens configured.
          <.link navigate={~p"/api_tokens/new"} class="text-blue-600 hover:text-blue-500">
            Create one
          </.link>
          to start using the platform.
        </p>
      <% end %>
    </section>

    <.back navigate={~p"/users"}>Back to users</.back>

    <.modal
      :if={@live_action == :update_tokens}
      id="api-token-modal"
      show
      on_cancel={JS.patch(~p"/users/#{@user}")}
    >
      <.live_component
        module={PanicWeb.UserLive.FormComponent}
        id={@user.id}
        title={@page_title}
        action={@live_action}
        current_user={@current_user}
        user={@user}
        navigate={~p"/users/#{@user}"}
      />
    </.modal>

    <.modal
      :if={@live_action == :new_network}
      id="new-network-modal"
      show
      on_cancel={JS.patch(~p"/users/#{@user}")}
    >
      <.live_component
        module={PanicWeb.NetworkLive.FormComponent}
        id={:new}
        title={@page_title}
        action={@live_action}
        current_user={@current_user}
        network={nil}
        navigate={~p"/users/#{@user}"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"user_id" => id}, _, socket) do
    case Ash.get(Panic.Accounts.User, id, actor: socket.assigns.current_user) do
      {:ok, user} ->
        networks = Ash.read!(Network, actor: socket.assigns.current_user)

        # Load user's API tokens
        user_with_tokens = Ash.load!(user, :api_tokens, actor: socket.assigns.current_user)
        api_tokens = user_with_tokens.api_tokens

        {:noreply,
         socket
         |> assign(:page_title, page_title(socket.assigns.live_action))
         |> assign(user: user, networks: networks, api_tokens: api_tokens)}

      {:error, _error} ->
        {:noreply, push_navigate(socket, to: ~p"/404")}
    end
  end

  @impl true
  def handle_info({PanicWeb.UserLive.FormComponent, {:saved, user}}, socket) do
    {:noreply, assign(socket, user: user)}
  end

  @impl true
  def handle_info({PanicWeb.NetworkLive.FormComponent, {:saved, _network}}, socket) do
    # do nothing, because it re-triggers a handle_params, where we just read all the networks from the db
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_network", %{"id" => id}, socket) do
    network = Ash.get!(Network, id, actor: socket.assigns.current_user)
    Ash.destroy!(network, actor: socket.assigns.current_user)

    # Reload networks after deletion
    networks = Ash.read!(Network, actor: socket.assigns.current_user)

    {:noreply, assign(socket, :networks, networks)}
  end

  defp page_title(:show), do: "Show User"
  defp page_title(:update_tokens), do: "Update API Tokens"
  defp page_title(:new_network), do: "Add Network"
end
