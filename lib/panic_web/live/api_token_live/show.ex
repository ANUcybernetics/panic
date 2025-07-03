defmodule PanicWeb.APITokenLive.Show do
  @moduledoc """
  LiveView for displaying a single API token.
  """
  use PanicWeb, :live_view

  alias Panic.Accounts.APIToken

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      API Token: {@api_token.name}
      <:subtitle>Manage your API credentials</:subtitle>
      <:actions>
        <.link patch={~p"/api_tokens/#{@api_token}/show/edit"} phx-click={JS.push_focus()}>
          <.button>Edit token</.button>
        </.link>
      </:actions>
    </.header>

    <.list>
      <:item title="Name">{@api_token.name}</:item>
      <:item title="Anonymous Access">
        <span :if={@api_token.allow_anonymous_use} class="inline-flex items-center rounded-md bg-blue-50 px-2 py-1 text-xs font-medium text-blue-700 ring-1 ring-inset ring-blue-700/10">
          Enabled
        </span>
        <span :if={!@api_token.allow_anonymous_use} class="inline-flex items-center rounded-md bg-gray-50 px-2 py-1 text-xs font-medium text-gray-600 ring-1 ring-inset ring-gray-500/10">
          Disabled
        </span>
      </:item>
      <:item title="Created">{Calendar.strftime(@api_token.inserted_at, "%B %d, %Y at %I:%M %p")}</:item>
      <:item title="Last Updated">{Calendar.strftime(@api_token.updated_at, "%B %d, %Y at %I:%M %p")}</:item>
    </.list>

    <div class="mt-8">
      <h3 class="text-base font-semibold leading-6 text-gray-900">Platform Tokens</h3>
      <dl class="mt-5 grid grid-cols-1 gap-5 sm:grid-cols-3">
        <div class="overflow-hidden rounded-lg bg-white px-4 py-5 shadow sm:p-6">
          <dt class="truncate text-sm font-medium text-gray-500">OpenAI</dt>
          <dd class="mt-1 text-sm text-gray-900">
            <span :if={@api_token.openai_token} class="font-mono">
              {String.slice(@api_token.openai_token, 0..10)}...
            </span>
            <span :if={!@api_token.openai_token} class="text-gray-400">Not configured</span>
          </dd>
        </div>
        <div class="overflow-hidden rounded-lg bg-white px-4 py-5 shadow sm:p-6">
          <dt class="truncate text-sm font-medium text-gray-500">Replicate</dt>
          <dd class="mt-1 text-sm text-gray-900">
            <span :if={@api_token.replicate_token} class="font-mono">
              {String.slice(@api_token.replicate_token, 0..10)}...
            </span>
            <span :if={!@api_token.replicate_token} class="text-gray-400">Not configured</span>
          </dd>
        </div>
        <div class="overflow-hidden rounded-lg bg-white px-4 py-5 shadow sm:p-6">
          <dt class="truncate text-sm font-medium text-gray-500">Gemini</dt>
          <dd class="mt-1 text-sm text-gray-900">
            <span :if={@api_token.gemini_token} class="font-mono">
              {String.slice(@api_token.gemini_token, 0..10)}...
            </span>
            <span :if={!@api_token.gemini_token} class="text-gray-400">Not configured</span>
          </dd>
        </div>
      </dl>
    </div>

    <div class="mt-8">
      <h3 class="text-base font-semibold leading-6 text-gray-900">Vestaboard Tokens</h3>
      <dl class="mt-5 grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
        <div :for={idx <- 1..4} class="overflow-hidden rounded-lg bg-white px-4 py-5 shadow sm:p-6">
          <dt class="truncate text-sm font-medium text-gray-500">Vestaboard Panic {idx}</dt>
          <dd class="mt-1 text-sm text-gray-900">
            <span :if={Map.get(@api_token, String.to_atom("vestaboard_panic_#{idx}_token"))} class="font-mono">
              {String.slice(Map.get(@api_token, String.to_atom("vestaboard_panic_#{idx}_token")), 0..10)}...
            </span>
            <span :if={!Map.get(@api_token, String.to_atom("vestaboard_panic_#{idx}_token"))} class="text-gray-400">
              Not configured
            </span>
          </dd>
        </div>
      </dl>
    </div>

    <.back navigate={~p"/api_tokens"}>Back to tokens</.back>

    <.modal :if={@live_action == :edit} id="api_token-modal" show on_cancel={JS.patch(~p"/api_tokens/#{@api_token}")}>
      <.live_component
        module={PanicWeb.APITokenLive.FormComponent}
        id={@api_token.id}
        title={@page_title}
        action={@live_action}
        api_token={@api_token}
        current_user={@current_user}
        patch={~p"/api_tokens/#{@api_token}"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    api_token = get_api_token!(id, socket.assigns.current_user)
    
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:api_token, api_token)}
  end

  @impl true
  def handle_info({PanicWeb.APITokenLive.FormComponent, {:saved, api_token}}, socket) do
    {:noreply, assign(socket, :api_token, api_token)}
  end

  defp page_title(:show), do: "Show API Token"
  defp page_title(:edit), do: "Edit API Token"

  defp get_api_token!(id, actor) do
    APIToken
    |> Ash.get!(id, actor: actor)
  end
end