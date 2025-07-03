defmodule PanicWeb.APITokenLive.Index do
  @moduledoc """
  LiveView for managing API tokens.
  """
  use PanicWeb, :live_view
  
  alias Panic.Accounts.APIToken
  
  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      API Tokens
      <:actions>
        <.link patch={~p"/api_tokens/new"}>
          <.button>New Token Set</.button>
        </.link>
      </:actions>
    </.header>

    <.table
      id="api_tokens"
      rows={@streams.api_tokens}
      row_click={fn {_id, api_token} -> JS.navigate(~p"/api_tokens/#{api_token}") end}
    >
      <:col :let={{_id, api_token}} label="Name">{api_token.name}</:col>
      <:col :let={{_id, api_token}} label="Platforms">
        <div class="flex gap-2">
          <span :if={api_token.openai_token} class="inline-flex items-center rounded-md bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20">OpenAI</span>
          <span :if={api_token.replicate_token} class="inline-flex items-center rounded-md bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20">Replicate</span>
          <span :if={api_token.gemini_token} class="inline-flex items-center rounded-md bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20">Gemini</span>
        </div>
      </:col>
      <:col :let={{_id, api_token}} label="Anonymous Access">
        <span :if={api_token.allow_anonymous_use} class="inline-flex items-center rounded-md bg-blue-50 px-2 py-1 text-xs font-medium text-blue-700 ring-1 ring-inset ring-blue-700/10">Yes</span>
        <span :if={!api_token.allow_anonymous_use} class="inline-flex items-center rounded-md bg-gray-50 px-2 py-1 text-xs font-medium text-gray-600 ring-1 ring-inset ring-gray-500/10">No</span>
      </:col>
      <:col :let={{_id, api_token}} label="Updated">{Calendar.strftime(api_token.updated_at, "%b %d, %Y")}</:col>
      <:action :let={{_id, api_token}}>
        <div class="sr-only">
          <.link navigate={~p"/api_tokens/#{api_token}"}>Show</.link>
        </div>
        <.link patch={~p"/api_tokens/#{api_token}/edit"}>Edit</.link>
      </:action>
      <:action :let={{id, api_token}}>
        <.link
          phx-click={JS.push("delete", value: %{id: api_token.id}) |> hide("##{id}")}
          data-confirm="Are you sure?"
        >
          Delete
        </.link>
      </:action>
    </.table>

    <.modal :if={@live_action in [:new, :edit]} id="api_token-modal" show on_cancel={JS.patch(~p"/api_tokens")}>
      <.live_component
        module={PanicWeb.APITokenLive.FormComponent}
        id={@api_token.id || :new}
        title={@page_title}
        action={@live_action}
        api_token={@api_token}
        current_user={@current_user}
        patch={~p"/api_tokens"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> stream(:api_tokens, list_api_tokens(socket.assigns.current_user))
     |> assign_new(:current_user, fn -> nil end)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit API Token")
    |> assign(:api_token, get_api_token!(id, socket.assigns.current_user))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New API Token")
    |> assign(:api_token, %APIToken{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "API Tokens")
    |> assign(:api_token, nil)
  end

  @impl true
  def handle_info({PanicWeb.APITokenLive.FormComponent, {:saved, api_token}}, socket) do
    {:noreply, stream_insert(socket, :api_tokens, api_token)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    api_token = get_api_token!(id, socket.assigns.current_user)
    {:ok, _} = Ash.destroy(api_token, actor: socket.assigns.current_user)

    {:noreply, stream_delete(socket, :api_tokens, api_token)}
  end

  defp list_api_tokens(actor) do
    APIToken
    |> Ash.read!(actor: actor)
  end

  defp get_api_token!(id, actor) do
    APIToken
    |> Ash.get!(id, actor: actor)
  end
end