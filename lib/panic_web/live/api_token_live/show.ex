defmodule PanicWeb.APITokenLive.Show do
  use PanicWeb, :live_view

  alias Panic.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:api_token, Accounts.get_api_token!(id))}
  end

  defp page_title(:show), do: "Show Api tokens"
  defp page_title(:edit), do: "Edit Api tokens"
end
