defmodule PanicWeb.NetworkLive.Info do
  @moduledoc false
  use PanicWeb, :live_view

  import PanicWeb.PanicComponents

  alias Panic.Engine.Network
  alias PanicWeb.DisplayStreamer

  @impl true
  def render(%{live_action: :all} = assigns) do
    ~H"""
    <div class="prose prose-purple">
      <h2>QR codes</h2>
      <%= for network <- Ash.read!(Panic.Engine.Network, actor: @current_user) do %>
        <ol>
          <li>
            <.link patch={~p"/networks/#{network.id}/info/qr"}>
              <%= network.name %>
            </.link>
          </li>
        </ol>
      <% end %>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="prose prose-purple">
      <h2>Network name: <%= @network.name %></h2>
      <section :if={@network.description}>
        <h2>Description</h2>
        <%= @network.description |> MDEx.to_html!() |> raw %>
      </section>
      <section>
        <h2>Models</h2>
        <p>The GenAI models in this network are:</p>
        <ol>
          <%= for model <- non_vestaboard_models(@network) do %>
            <li>
              <.link href={Panic.Model.model_url(model)} target="_blank"><%= model.name %></.link>
              (<%= model.input_type %> -> <%= model.output_type %>)
            </li>
          <% end %>
        </ol>
      </section>

      <p>
        Click the model name for details, or for information about how PANIC! works, see the <.link patch={
          ~p"/about"
        }>about page</.link>.
      </p>

      <section>
        <h2>Last input</h2>
        <div>
          <%= if @genesis_invocation do %>
            <%= @genesis_invocation.input %>
          <% else %>
            <em>loading...</em>
          <% end %>
        </div>
        <h2>Current output</h2>
        <%= if @genesis_invocation do %>
          <.display invocations={@streams.invocations} display={@display} />
        <% else %>
          <em>loading...</em>
        <% end %>
      </section>
    </div>

    <.modal
      show={@live_action == :qr}
      id="qr-modal"
      on_cancel={JS.patch(~p"/networks/#{@network.id}/info/")}
    >
      <.qr_code text={@qr_text} />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"network_id" => network_id}, _, socket) do
    case get_network(network_id, socket.assigns) do
      {:ok, network} ->
        {:noreply,
         socket
         |> assign(:page_title, "Network #{network_id} terminal")
         |> assign(:qr_text, url(socket, ~p"/networks/#{network.id}/info/"))
         |> DisplayStreamer.configure_invocation_stream(network, {:single, 0, 1})}

      {:error, _error} ->
        {:noreply, push_navigate(socket, to: ~p"/404")}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "invocation:" <> _} = message, socket) do
    # for this view, only show completed ones
    # no need to show the panic loading screen
    if message.payload.data.state == :completed do
      DisplayStreamer.handle_invocation_message(message, socket)
    else
      {:noreply, socket}
    end
  end

  defp non_vestaboard_models(network) do
    network.models
    |> Panic.Model.model_ids_to_model_list()
    |> Enum.reject(fn m -> m.platform == Panic.Platforms.Vestaboard end)
  end

  # this is a hack - because these live actions indicate routes that are auth-optional
  # a nicer way to do that would be to have the policy checks know which on_mount
  # hooks had been run, and then to check the policy based on that
  defp get_network(network_id, %{live_action: :info}) do
    Ash.get(Network, network_id, authorize?: false)
  end

  defp get_network(network_id, assigns) do
    Ash.get(Network, network_id, actor: assigns.current_user)
  end
end
