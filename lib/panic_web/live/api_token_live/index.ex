defmodule PanicWeb.APITokenLive.Index do
  use PanicWeb, :live_view

  alias Panic.Accounts
  alias Panic.Accounts.APIToken

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :api_tokens, list_api_tokens(socket.assigns.current_user))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit API token")
    |> assign(:api_token, Accounts.get_api_token!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New API token")
    |> assign(:api_token, %APIToken{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing API tokens")
    |> assign(:api_token, nil)
  end

  @impl true
  def handle_info({PanicWeb.APITokenLive.FormComponent, {:saved, api_token}}, socket) do
    {:noreply, stream_insert(socket, :api_tokens, api_token)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    api_token = Accounts.get_api_token!(id)
    {:ok, _} = Accounts.delete_api_token(api_token)

    {:noreply, stream_delete(socket, :api_tokens, api_token)}
  end

  defp list_api_tokens(%Accounts.User{} = user) do
    Accounts.list_api_tokens(user)
  end
end
