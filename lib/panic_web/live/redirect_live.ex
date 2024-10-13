defmodule PanicWeb.RedirectLive do
  @moduledoc false
  use PanicWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"redirect" => redirect}, _session, socket) do
    path =
      case String.graphemes(redirect) do
        ["s" | invocation_graphemes] -> ~p"/display/static/#{Enum.join(invocation_graphemes)}/"
        [network_id, offset, stride] -> ~p"/networks/#{network_id}/display/single/#{offset}/#{stride}/"
      end

    {:noreply, push_navigate(socket, to: path)}
  end
end
