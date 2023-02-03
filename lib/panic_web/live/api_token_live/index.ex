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
    |> assign(:api_token, Accounts.get_api_token!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Api tokens")
    |> assign(:api_token, %APIToken{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Api tokens")
    |> assign(:api_token, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    api_token = Accounts.get_api_token!(id)
    {:ok, _} = Accounts.delete_api_token(api_token)

    {:noreply, assign(socket, :api_tokens_collection, list_api_tokens())}
  end

  defp list_api_tokens do
    # Accounts.list_api_tokens() # need to pass the user in
    []
  end
end
