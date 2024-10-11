defmodule PanicWeb.NetworkLive.Info do
  @moduledoc false
  use PanicWeb, :live_view

  import PanicWeb.PanicComponents

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
        <ol>
          <%= for model <- non_vestaboard_models(@network) do %>
            <li>
              <.link href={Panic.Model.model_url(model)} target="_blank"><%= model.name %></.link>
              (<%= model.input_type %> -> <%= model.output_type %>)
            </li>
          <% end %>
        </ol>
      </section>

      <section>
        <h2>Last input</h2>
        <div><%= (@genesis_invocation && @genesis_invocation.input) || "unknown" %></div>
        <h2>Current status</h2>
        <.display invocations={@streams.invocations} display={@display} />
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
    {:ok, DisplayStreamer.configure_invocation_stream(socket, {:single, 0, 1})}
  end

  @impl true
  def handle_params(%{"network_id" => network_id}, _, socket) do
    case Ash.get(Panic.Engine.Network, network_id, actor: socket.assigns.current_user) do
      {:ok, network} ->
        {:noreply,
         socket
         |> assign(:page_title, "Network #{network_id} terminal")
         |> assign(:qr_text, url(socket, ~p"/networks/#{network.id}/info/"))
         |> DisplayStreamer.subscribe_to_invocation_stream(network)}

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
end
