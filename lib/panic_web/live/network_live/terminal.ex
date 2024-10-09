defmodule PanicWeb.NetworkLive.Terminal do
  @moduledoc false
  use PanicWeb, :live_view
  use PanicWeb.DisplayStreamer

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-dvh grid place-items-center">
      <div class="w-1/2">
        <.live_component
          class="mb-16"
          module={PanicWeb.NetworkLive.TerminalComponent}
          network={@network}
          genesis_invocation={@genesis_invocation}
          current_user={@current_user}
          id={@network.id}
        />

        <p><span class="text-purple-300/50">Last input:</span> <span :if={@genesis_invocation}><%= @genesis_invocation.input %></span></p>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket, layout: {PanicWeb.Layouts, :display}}
  end

  @impl true
  def handle_params(%{"network_id" => network_id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Network #{network_id} terminal")
     |> configure_display_stream(network_id, {:single, 0, 1})}
  end
end
