defmodule PanicWeb.UserLive.Show do
  use PanicWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      User <%= @user.id %>: <%= @user.email %>
    </.header>

    <section>
      <div class="flex justify-between items-center mt-16">
        <h2 class="font-semibold">API Tokens</h2>
        <.link patch={~p"/users/#{@user}/update-tokens"} phx-click={JS.push_focus()}>
          <.button>Update API Tokens</.button>
        </.link>
      </div>

      <div id="token-list">
        <.list>
          <:item title="Replicate"><%= @user.replicate_token %></:item>
          <:item title="OpenAI"><%= @user.openai_token %></:item>
          <:item title="Vestaboard 1"><%= @user.vestaboard_panic_1_token %></:item>
          <:item title="Vestaboard 2"><%= @user.vestaboard_panic_2_token %></:item>
          <:item title="Vestaboard 3"><%= @user.vestaboard_panic_3_token %></:item>
          <:item title="Vestaboard 4"><%= @user.vestaboard_panic_4_token %></:item>
        </.list>
      </div>
    </section>

    <hr class="h-px my-8 bg-gray-300 border-0" />

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
            <.link patch={~p"/networks/#{network}/"} phx-click={JS.push_focus()}>
              <%= network.name %>
            </.link>
          </:col>
          <:col :let={network} label="Description"><%= network.description %></:col>
        </.table>
      <% else %>
        <p class="mt-8">User has no networks.</p>
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
        patch={~p"/users/#{@user}"}
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
        patch={~p"/users/#{@user}"}
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
    user =
      Panic.Accounts.User
      |> Ash.get!(id, actor: socket.assigns.current_user)

    networks = Ash.read!(Panic.Engine.Network, actor: socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(user: user, networks: networks)}
  end

  @impl true
  def handle_info({PanicWeb.UserLive.FormComponent, {:saved, user}}, socket) do
    {:noreply, assign(socket, user: user)}
  end

  @impl true
  def handle_info({PanicWeb.NetworkLive.FormComponent, {:saved, network}}, socket) do
    {:noreply, update(socket, :networks, &[network | &1])}
  end

  defp page_title(:show), do: "Show User"
  defp page_title(:update_tokens), do: "Update API Tokens"
  defp page_title(:new_network), do: "Add Network"
end
