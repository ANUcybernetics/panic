defmodule PanicWeb.InstallationLive.WatcherDisplay do
  @moduledoc """
  LiveView for displaying invocations through an installation's watcher configuration.

  This module bridges between the Installation's Watcher structs and the existing
  WatcherSubscriber display logic. Watchers are accessed by their unique name within
  the installation.
  """
  use PanicWeb, :live_view

  import PanicWeb.PanicComponents

  alias PanicWeb.TerminalAuth
  alias PanicWeb.WatcherSubscriber

  @impl true
  def render(assigns) do
    ~H"""
    <div
      :if={@display != nil && tuple_size(@display) == 3 && elem(@display, 0) == :grid}
      class={["px-4 pt-2 pb-4", show_terminal_qr?(@first_display?, @network) && "pr-[22vmin]"]}
    >
      <.live_component
        :if={@current_user}
        class="-mt-4 mb-4"
        module={PanicWeb.NetworkLive.TerminalComponent}
        network={@network}
        genesis_invocation={@genesis_invocation}
        current_user={@current_user}
        id={@network.id}
      />
      <p>
        <span class="text-purple-300/50">Last prompt:</span>
        <span :if={@genesis_invocation}>{@genesis_invocation.input}</span>
      </p>
    </div>
    <.display invocations={@streams.invocations} display={@display} />
    <.terminal_qr :if={show_terminal_qr?(@first_display?, @network)} url={@terminal_qr_url} />
    """
  end

  @impl true
  def mount(%{"id" => id, "watcher_name" => watcher_name} = _params, _session, socket) do
    case get_installation(id, socket.assigns) do
      {:ok, installation} ->
        case get_watcher_by_name(installation, watcher_name) do
          {:ok, watcher} ->
            display = watcher_to_display_tuple(watcher)
            network = installation.network

            if connected?(socket) do
              :timer.send_interval(TerminalAuth.qr_refresh_ms(), self(), :refresh_terminal_qr)
            end

            {:ok,
             socket
             |> assign(:page_title, "#{installation.name} - #{watcher.name}")
             |> assign(:installation, installation)
             |> assign(:watcher, watcher)
             |> assign(:watcher_name, watcher.name)
             |> assign(:first_display?, first_display?(installation, watcher))
             |> assign(:terminal_qr_url, TerminalAuth.terminal_url(network.id))
             |> WatcherSubscriber.configure_invocation_stream(network, display), layout: {PanicWeb.Layouts, :display}}

          {:error, :not_found} ->
            {:ok,
             socket
             |> put_flash(:error, "Watcher '#{watcher_name}' not found")
             |> push_navigate(to: ~p"/installations/#{installation}"), layout: {PanicWeb.Layouts, :app}}
        end

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Installation not found")
         |> push_navigate(to: ~p"/"), layout: {PanicWeb.Layouts, :app}}
    end
  end

  @impl true
  def handle_info(:refresh_terminal_qr, socket) do
    {:noreply, assign(socket, :terminal_qr_url, TerminalAuth.terminal_url(socket.assigns.network.id))}
  end

  def handle_info({PanicWeb.NetworkLive.TerminalComponent, {:genesis_invocation, genesis_invocation}}, socket) do
    {:noreply, assign(socket, :genesis_invocation, genesis_invocation)}
  end

  # the anonymous terminal's QR code goes on the installation's first screen
  # (a Vestaboard can't show one)
  defp first_display?(installation, watcher) do
    first = Enum.find(installation.watchers, &(&1.type != :vestaboard))
    first != nil and first.name == watcher.name
  end

  defp show_terminal_qr?(first_display?, network), do: first_display? and network.anon_terminal_minutes != nil

  # Convert watcher struct to display tuple format expected by WatcherSubscriber
  defp watcher_to_display_tuple(%{type: :grid, rows: rows, columns: columns}) do
    {:grid, rows, columns}
  end

  defp watcher_to_display_tuple(%{type: :single, offset: offset, stride: stride, show_invoking: show_invoking}) do
    {:single, offset, stride, show_invoking}
  end

  defp watcher_to_display_tuple(%{type: :vestaboard, offset: offset, stride: stride, show_invoking: show_invoking}) do
    # For now, treat vestaboard as single display
    # TODO: Implement vestaboard-specific handling later
    {:single, offset, stride, show_invoking}
  end

  defp get_installation(id, assigns) do
    Panic.Watcher.get_installation(id,
      actor: assigns[:current_user],
      authorize?: false,
      load: [:network]
    )
  end

  defp get_watcher_by_name(installation, name) do
    case Enum.find(installation.watchers, fn w -> w.name == name end) do
      nil -> {:error, :not_found}
      watcher -> {:ok, watcher}
    end
  end
end
