defmodule PanicWeb.InstallationLive.WatcherDisplay do
  @moduledoc """
  LiveView for displaying invocations through an installation's watcher configuration.

  This module bridges between the Installation's Watcher structs and the existing
  InvocationWatcher display logic.
  """
  use PanicWeb, :live_view

  import PanicWeb.PanicComponents

  alias Panic.Engine.Installation
  alias PanicWeb.InvocationWatcher

  @impl true
  def render(assigns) do
    ~H"""
    <div
      :if={@display != nil && tuple_size(@display) == 3 && elem(@display, 0) == :grid}
      class="px-4 pt-2 pb-4"
    >
      <.live_component
        :if={@current_user}
        class="-mt-4 mb-4"
        module={PanicWeb.NetworkLive.TerminalComponent}
        network={@network}
        genesis_invocation={@genesis_invocation}
        current_user={@current_user}
        lockout_seconds_remaining={@lockout_seconds_remaining}
        id={@network.id}
      />
      <p>
        <span class="text-purple-300/50">Last prompt:</span>
        <span :if={@genesis_invocation}>{@genesis_invocation.input}</span>
      </p>
    </div>
    <.display invocations={@streams.invocations} display={@display} />
    """
  end

  @impl true
  def mount(%{"id" => id, "index" => index} = _params, _session, socket) do
    case {parse_index(index), get_installation(id, socket.assigns)} do
      {{:ok, index}, {:ok, installation}} ->
        case get_watcher_at_index(installation, index) do
          {:ok, watcher} ->
            display = watcher_to_display_tuple(watcher)
            network = installation.network

            {:ok,
             socket
             |> assign(:page_title, "#{installation.name} - Watcher #{index}")
             |> assign(:installation, installation)
             |> assign(:watcher, watcher)
             |> assign(:watcher_index, index)
             |> InvocationWatcher.configure_invocation_stream(network, display), layout: {PanicWeb.Layouts, :display}}

          {:error, :not_found} ->
            {:ok,
             socket
             |> put_flash(:error, "Watcher not found at index #{index}")
             |> push_navigate(to: ~p"/installations/#{installation}"), layout: {PanicWeb.Layouts, :app}}
        end

      {_, {:error, _}} ->
        {:ok,
         socket
         |> put_flash(:error, "Installation not found")
         |> push_navigate(to: ~p"/"), layout: {PanicWeb.Layouts, :app}}

      {{:error, :invalid_index}, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Invalid watcher index")
         |> push_navigate(to: ~p"/"), layout: {PanicWeb.Layouts, :app}}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "invocation:" <> _} = message, socket) do
    InvocationWatcher.handle_invocation_message(message, socket)
  end

  @impl true
  def handle_info({PanicWeb.NetworkLive.TerminalComponent, {:genesis_invocation, genesis_invocation}}, socket) do
    {:noreply, assign(socket, :genesis_invocation, genesis_invocation)}
  end

  # Convert watcher struct to display tuple format expected by InvocationWatcher
  defp watcher_to_display_tuple(%{type: :grid, rows: rows, columns: columns}) do
    {:grid, rows, columns}
  end

  defp watcher_to_display_tuple(%{type: :single, offset: offset, stride: stride}) do
    {:single, offset, stride}
  end

  defp watcher_to_display_tuple(%{type: :vestaboard, offset: offset, stride: stride}) do
    # For now, treat vestaboard as single display
    # TODO: Implement vestaboard-specific handling later
    {:single, offset, stride}
  end

  defp get_installation(id, assigns) do
    # Anyone can view installation displays (no authentication required)
    Ash.get(Installation, id,
      actor: assigns[:current_user],
      authorize?: false,
      load: [:network]
    )
  end

  defp get_watcher_at_index(installation, index) do
    case Enum.at(installation.watchers, index) do
      nil -> {:error, :not_found}
      watcher -> {:ok, watcher}
    end
  end

  defp parse_index(index) when is_binary(index) do
    case Integer.parse(index) do
      {n, ""} when n >= 0 -> {:ok, n}
      _ -> {:error, :invalid_index}
    end
  end
end
