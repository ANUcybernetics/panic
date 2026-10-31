defmodule PanicWeb.InstallationLive.WatcherDisplay do
  @moduledoc """
  LiveView for displaying invocations through an installation's watcher configuration.

  This module bridges between the Installation's Watcher structs and the existing
  WatcherSubscriber display logic. Watchers are accessed by their unique name within
  the installation.

  The installation's first screen also shows a summary of the run in progress
  (see `PanicWeb.NetworkLive.RunSummary`) beside the QR code for the anonymous
  terminal. A single screen shows them in its corner; a grid gives them its
  last cell, so one big grid can be a whole installation.

  A single screen captions what it shows with the model that made it and what
  from (see `PanicWeb.PanicComponents.invocation_caption/1`), so a viewer can
  follow the chain from screen to screen.
  """
  @behaviour PanicWeb.WatcherSubscriber

  use PanicWeb, :live_view

  import PanicWeb.PanicComponents

  alias PanicWeb.NetworkLive.RunSummary
  alias PanicWeb.TerminalAuth
  alias PanicWeb.WatcherSubscriber

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.display flash={@flash}>
      <div :if={grid?(@display)} class="px-4 pt-2 pb-4">
        <p>
          <span class="text-purple-300/50">Initial prompt:</span>
          <span :if={@genesis_invocation}>{@genesis_invocation.input}</span>
        </p>
      </div>
      <.display
        invocations={@streams.invocations}
        display={@display}
        models={caption_models(@display, @network)}
        latest_sequence={@latest_sequence}
        text_reserve={text_reserve(@first_display?, @network)}
      >
        <:reserved_cell :if={@first_display?}>
          <.run_cell
            url={terminal_url(@network, @terminal_qr_url)}
            summary={@run_summary}
            models={@network.models}
          />
        </:reserved_cell>
      </.display>
      <.terminal_qr
        :if={
          @first_display? and not grid?(@display) and terminal_url(@network, @terminal_qr_url) != nil
        }
        url={@terminal_qr_url}
        summary={@run_summary}
        models={@network.models}
      />
    </Layouts.display>
    """
  end

  # Kiosks keep a display open across deploys, and LiveView would otherwise
  # render the new markup with the old page's styles and scripts, so a display
  # whose assets are out of date reloads itself.
  @impl true
  def mount(%{"id" => id, "watcher_name" => watcher_name} = params, session, socket) do
    if static_changed?(socket) do
      {:ok, redirect(socket, to: ~p"/i/#{id}/#{watcher_name}")}
    else
      mount_display(params, session, socket)
    end
  end

  defp mount_display(%{"id" => id, "watcher_name" => watcher_name} = _params, _session, socket) do
    case get_installation(id, socket.assigns) do
      {:ok, installation} ->
        case get_watcher_by_name(installation, watcher_name) do
          {:ok, watcher} ->
            display = watcher_to_display_tuple(watcher)
            network = installation.network
            first_display? = first_display?(installation, watcher)

            if connected?(socket) and first_display? do
              :timer.send_interval(TerminalAuth.qr_refresh_ms(), self(), :refresh_terminal_qr)
            end

            {:ok,
             socket
             |> assign(:page_title, "#{installation.name} - #{watcher.name}")
             |> assign(:installation, installation)
             |> assign(:watcher, watcher)
             |> assign(:watcher_name, watcher.name)
             |> assign(:first_display?, first_display?)
             |> assign(
               :run_summary,
               if(first_display?, do: RunSummary.load(network.current_run_number))
             )
             |> assign(:terminal_qr_url, TerminalAuth.terminal_url(network.id))
             |> WatcherSubscriber.configure_invocation_stream(network, display,
               reserved_cells: if(first_display? and grid?(display), do: 1, else: 0)
             )}

          {:error, :not_found} ->
            {:ok,
             socket
             |> put_flash(:error, "Watcher '#{watcher_name}' not found")
             |> push_navigate(to: ~p"/installations/#{installation}")}
        end

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Installation not found")
         |> push_navigate(to: ~p"/")}
    end
  end

  # only the first screen shows the run summary, so only it keeps one
  @impl WatcherSubscriber
  def handle_invocation(invocation, %{assigns: %{first_display?: true}} = socket) do
    assign(socket, :run_summary, RunSummary.update(socket.assigns.run_summary, invocation))
  end

  def handle_invocation(_invocation, socket), do: socket

  @impl true
  def handle_info(:refresh_terminal_qr, socket) do
    {:noreply, assign(socket, :terminal_qr_url, TerminalAuth.terminal_url(socket.assigns.network.id))}
  end

  # the anonymous terminal's QR code goes on the installation's first screen
  # (a Vestaboard can't show one)
  defp first_display?(installation, watcher) do
    first = Enum.find(installation.watchers, &(&1.type != :vestaboard))
    first != nil and first.name == watcher.name
  end

  defp terminal_url(%{anon_terminal_minutes: nil}, _url), do: nil
  defp terminal_url(_network, url), do: url

  defp grid?(display), do: elem(display, 0) == :grid

  # a single screen's text keeps clear of its caption, and on the first screen
  # of the QR code and heads-up display too (both sit at the bottom)
  defp text_reserve(first_display?, network) do
    if first_display? and network.anon_terminal_minutes != nil, do: 0.36, else: 0.12
  end

  # a grid's cells are too small for captions
  defp caption_models({:single, _offset, _stride, _show_invoking}, %{models: [_ | _] = models}), do: models

  defp caption_models(_display, _network), do: nil

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
