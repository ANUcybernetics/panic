defmodule PanicWeb.APITokenLive.Index do
  use PanicWeb, :live_view

  alias Panic.Accounts
  alias Panic.Accounts.APIToken

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :api_tokens_collection, list_api_tokens())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Api tokens")
    |> assign(:api_tokens, Accounts.get_api_tokens!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Api tokens")
    |> assign(:api_tokens, %APIToken{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Api tokens")
    |> assign(:api_tokens, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    api_tokens = Accounts.get_api_tokens!(id)
    {:ok, _} = Accounts.delete_api_tokens(api_tokens)

    {:noreply, assign(socket, :api_tokens_collection, list_api_tokens())}
  end

  defp list_api_tokens do
    Accounts.list_api_tokens()
  end
end
