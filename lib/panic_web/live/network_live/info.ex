defmodule PanicWeb.NetworkLive.Info do
  @moduledoc false
  use PanicWeb, :live_view

  import PanicWeb.PanicComponents

  alias Panic.Engine.Network
  alias PanicWeb.TerminalAuth
  alias PanicWeb.WatcherSubscriber

  @impl true
  def render(%{live_action: :all} = assigns) do
    ~H"""
    <div class="prose prose-purple">
      <h2>QR codes</h2>
      <%= for network <- Ash.read!(Panic.Engine.Network, actor: @current_user) do %>
        <ol>
          <li>
            <.link patch={~p"/networks/#{network.id}/info/qr"}>
              {network.name}
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
      <h2>Network name: {@network.name}</h2>
      <%= if @network.description do %>
        {@network.description |> MDEx.to_html!() |> raw}
      <% end %>
      <h2>Models</h2>
      <p>The GenAI models in this network are:</p>
      <ol>
        <%= for model <- all_models(@network) do %>
          <li>
            <.link href={Panic.Model.model_url(model)} target="_blank">{model.name}</.link>
            ({model.input_type} -> {model.output_type})
          </li>
        <% end %>
      </ol>

      <p>
        Click the model name in the list above for more about that particular GenAI model, or head to the
        <.link patch={~p"/about"}>about page</.link>
        for information about how PANIC! works.
      </p>

      <h2>Last prompt</h2>
      <div>
        <%= if @genesis_invocation do %>
          {@genesis_invocation.input}
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
    </div>

    <.modal
      show={@live_action == :qr}
      id="qr-modal"
      on_cancel={JS.patch(~p"/networks/#{@network.id}/info/")}
    >
      <.qr_code text={@qr_text} title="scan to prompt" />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    # Schedule periodic QR code refresh every 5 minutes
    if connected?(socket) do
      :timer.send_interval(300_000, self(), :refresh_qr_code)
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"network_id" => network_id}, _, socket) do
    case get_network(network_id, socket.assigns) do
      {:ok, network} ->
        # Generate URL based on live action
        qr_url =
          case socket.assigns.live_action do
            :qr -> TerminalAuth.generate_terminal_url(network.id)
            _ -> url(socket, ~p"/networks/#{network.id}/info/")
          end

        {:noreply,
         socket
         |> assign(:page_title, "Network #{network_id} terminal")
         |> assign(:qr_text, qr_url)
         |> WatcherSubscriber.configure_invocation_stream(network, {:single, 0, 1, false})}

      {:error, _error} ->
        {:noreply, push_navigate(socket, to: ~p"/404")}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "invocation:" <> _} = message, socket) do
    WatcherSubscriber.handle_invocation_message(message, socket)
  end

  @impl true
  def handle_info(:refresh_qr_code, socket) do
    # Only refresh if we're showing the QR modal
    if socket.assigns.live_action == :qr do
      network_id = socket.assigns.network.id
      new_qr_url = TerminalAuth.generate_terminal_url(network_id)
      {:noreply, assign(socket, :qr_text, new_qr_url)}
    else
      {:noreply, socket}
    end
  end

  defp all_models(network) do
    network.models
    |> Enum.map(&Panic.Model.by_id/1)
    |> Enum.reject(&is_nil/1)
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
