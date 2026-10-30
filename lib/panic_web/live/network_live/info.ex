defmodule PanicWeb.NetworkLive.Info do
  @moduledoc false
  use PanicWeb, :live_view

  import PanicWeb.PanicComponents

  alias PanicWeb.TerminalAuth
  alias PanicWeb.WatcherSubscriber

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="prose prose-purple max-w-none">
        <h2>Network name: {@network.name}</h2>
        <div :if={@network.description}>
          {@network.description |> MDEx.to_html!() |> raw}
        </div>
        <h2>Models</h2>
        <p>The GenAI models in this network are:</p>
        <ol>
          <li :for={model <- all_models(@network)}>
            <.link :if={model.platform} href={Panic.Model.model_url(model)} target="_blank">
              {model.name}
            </.link>
            <span :if={!model.platform} class="text-base-content/60">{model.name}</span>
            ({model.input_type} -> {model.output_type})
          </li>
        </ol>

        <p>
          Click the model name in the list above for more about that particular GenAI model, or head to the
          <.link patch={~p"/about"}>about page</.link>
          for information about how PANIC! works.
        </p>

        <h2>Initial prompt</h2>
        <div>
          <em :if={!@genesis_invocation}>loading...</em>
          {@genesis_invocation && @genesis_invocation.input}
        </div>
        <h2>Current output</h2>
        <.display :if={@genesis_invocation} invocations={@streams.invocations} display={@display} />
        <em :if={!@genesis_invocation}>loading...</em>
      </div>

      <.modal
        show={@live_action == :qr}
        id="qr-modal"
        on_cancel={JS.patch(~p"/networks/#{@network.id}/info/")}
      >
        <.qr_code :if={@qr_text} text={@qr_text} title="scan to prompt" />
        <p :if={!@qr_text} class="text-center">
          This network's anonymous terminal is off. Turn it on by giving it a number of minutes in the network's settings.
        </p>
      </.modal>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    # each QR code opens a terminal for a limited time, so keep issuing new ones
    if connected?(socket) do
      :timer.send_interval(TerminalAuth.qr_refresh_ms(), self(), :refresh_qr_code)
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"network_id" => network_id}, _, socket) do
    case get_network(network_id, socket.assigns) do
      {:ok, network} ->
        {:noreply,
         socket
         |> assign(:page_title, "Network #{network_id} terminal")
         |> assign(:qr_text, terminal_qr_text(network))
         |> WatcherSubscriber.configure_invocation_stream(network, {:single, 0, 1, false})}

      {:error, _error} ->
        {:noreply, push_navigate(socket, to: ~p"/404")}
    end
  end

  @impl true
  def handle_info(:refresh_qr_code, socket) do
    {:noreply, assign(socket, :qr_text, terminal_qr_text(socket.assigns.network))}
  end

  defp terminal_qr_text(%{anon_terminal_minutes: nil}), do: nil
  defp terminal_qr_text(network), do: TerminalAuth.terminal_url(network.id)

  defp all_models(network) do
    Enum.map(network.models, &PanicWeb.NetworkLive.NetworkHelpers.get_model_or_placeholder/1)
  end

  # this is a hack - because these live actions indicate routes that are auth-optional
  # a nicer way to do that would be to have the policy checks know which on_mount
  # hooks had been run, and then to check the policy based on that
  defp get_network(network_id, %{live_action: :info}) do
    Panic.Engine.get_network(network_id, authorize?: false)
  end

  defp get_network(network_id, assigns) do
    Panic.Engine.get_network(network_id, actor: assigns.current_user)
  end
end
