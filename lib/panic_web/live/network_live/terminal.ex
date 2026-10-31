defmodule PanicWeb.NetworkLive.Terminal do
  @moduledoc """
  A terminal for prompting a network. Signed-in users can always open one;
  anyone else needs a token from the QR code on an installation's first screen
  (see `PanicWeb.TerminalAuth`), and the terminal closes when it expires.

  It also shows the run's latest output, as a single screen would, and its
  stats (see `PanicWeb.NetworkLive.RunSummary`): its estimated energy for
  everyone, and its estimated cost only for signed-in users.
  """
  @behaviour PanicWeb.WatcherSubscriber

  use PanicWeb, :live_view

  import PanicWeb.PanicComponents, only: [countdown: 1, invocation: 1, run_stats: 1]

  alias PanicWeb.NetworkLive.NetworkHelpers
  alias PanicWeb.NetworkLive.RunSummary
  alias PanicWeb.TerminalAuth
  alias PanicWeb.WatcherSubscriber

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.display flash={@flash}>
      <style>
        /* the display layout's 200% suits a big screen, but this page is also
           what a phone shows after scanning the QR code */
        :root {
          font-size: clamp(100%, 2.5vw, 200%);
        }
      </style>
      <%!-- the display layout doesn't scroll, but a phone may need to --%>
      <div class="h-dvh overflow-y-auto">
        <%!-- the prompt comes first, so nothing above it changes as the run goes and
              it never moves under a phone user's thumb --%>
        <div class="terminal-container mx-auto max-w-5xl p-4 sm:p-8">
          <.live_component
            module={PanicWeb.NetworkLive.TerminalComponent}
            network={@network}
            genesis_invocation={@genesis_invocation}
            current_user={@network_user}
            expires_at={@expires_at}
            id={@network.id}
          />
          <p :if={@expires_at} id="terminal-expiry" class="mt-2 text-sm text-base-content/60">
            This terminal closes in
            <.countdown id="terminal-expiry-countdown" target={@expires_at} />.
          </p>
          <p class="mt-6 break-words text-primary-content sm:mt-8">
            <span class="text-base-content/60">Current run:</span>
            <span :if={@genesis_invocation}>{@genesis_invocation.input}</span>
          </p>
          <div class="mt-4 grid items-start gap-4 sm:grid-cols-[minmax(0,3fr)_minmax(0,2fr)]">
            <.latest_output invocations={@streams.invocations} />
            <.run_stats
              :if={@run_summary}
              id="run-summary"
              summary={@run_summary}
              show_cost?={!!@current_user}
              class="flex flex-wrap gap-x-6 gap-y-1 text-sm text-base-content/60 [&_dd]:inline [&_dd]:text-base-content [&_dt]:inline [&_dt]:after:content-['_']"
            />
          </div>
          <%!-- a new tab, so reading it doesn't close an anonymous terminal --%>
          <p class="mt-6 text-sm sm:mt-8">
            <.link id="terminal-about" href={~p"/about"} target="_blank" class="link">
              What is PANIC!?
            </.link>
          </p>
        </div>
      </div>
    </Layouts.display>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok, assign(socket, token: params["token"], expires_at: nil)}
  end

  @impl true
  def handle_params(%{"network_id" => network_id}, _, socket) do
    # no actor: anonymous terminals need the network too
    with {:ok, network} <- Panic.Engine.get_network(network_id, authorize?: false, load: [:user]),
         {:ok, socket} <- authorize(socket, network) do
      case NetworkHelpers.check_network_models(network.models) do
        {:ok, _models} ->
          {:noreply,
           socket
           |> assign(:page_title, "Network #{network_id} terminal")
           |> assign(:network_user, network.user)
           |> assign(:run_summary, RunSummary.load(network.current_run_number))
           |> WatcherSubscriber.watch(network)
           |> WatcherSubscriber.configure_invocation_stream(network, {:single, 0, 1, false})}

        {:error, missing_ids} ->
          {:noreply, NetworkHelpers.handle_broken_network(socket, network, missing_ids)}
      end
    else
      {:error, :expired} ->
        {:noreply, push_navigate(socket, to: ~p"/networks/#{network_id}/terminal/expired")}

      {:error, _not_found} ->
        {:noreply, push_navigate(socket, to: ~p"/404")}
    end
  end

  @impl WatcherSubscriber
  def handle_invocation(invocation, socket) do
    assign(socket, :run_summary, RunSummary.update(socket.assigns.run_summary, invocation))
  end

  @impl true
  def handle_info({PanicWeb.NetworkLive.TerminalComponent, {:genesis_invocation, genesis_invocation}}, socket) do
    {:noreply, assign(socket, :genesis_invocation, genesis_invocation)}
  end

  def handle_info(:expired, socket) do
    {:noreply, push_navigate(socket, to: ~p"/networks/#{socket.assigns.network}/terminal/expired")}
  end

  # One output at a time, captioned with the model that made it: shown together,
  # an image and a caption don't say which was made from which.
  attr :invocations, :any, required: true

  defp latest_output(assigns) do
    ~H"""
    <div id="latest-output" phx-update="stream">
      <figure :for={{id, invocation} <- @invocations} id={id}>
        <div class="overflow-hidden rounded">
          <.invocation
            id={"#{id}-output"}
            invocation={invocation}
            model={NetworkHelpers.get_model_or_placeholder(invocation.model)}
            fit_text={0.0}
          />
        </div>
        <.output_caption
          invocation={invocation}
          model={NetworkHelpers.get_model_or_placeholder(invocation.model)}
        />
      </figure>
    </div>
    """
  end

  attr :invocation, :any, required: true
  attr :model, :any, required: true

  defp output_caption(assigns) do
    ~H"""
    <figcaption class="mt-2 text-sm text-base-content/60">
      {if @invocation.state == :completed, do: "#{@model.output_type} by", else: "now running"}
      <span id="latest-output-model" class="text-base-content">{@model.name}</span>
      · invocation <span id="latest-output-sequence">{@invocation.sequence_number}</span>
    </figcaption>
    """
  end

  defp authorize(%{assigns: %{current_user: %{}}} = socket, _network), do: {:ok, socket}

  defp authorize(socket, network) do
    case TerminalAuth.verify(socket.assigns.token, network) do
      {:ok, expires_at} ->
        if connected?(socket) and is_nil(socket.assigns.expires_at) do
          Process.send_after(
            self(),
            :expired,
            max(DateTime.diff(expires_at, DateTime.utc_now(), :millisecond), 0)
          )
        end

        {:ok, assign(socket, :expires_at, expires_at)}

      # a missing, invalid or expired token, or a network without the anonymous terminal
      {:error, _reason} ->
        {:error, :expired}
    end
  end
end
