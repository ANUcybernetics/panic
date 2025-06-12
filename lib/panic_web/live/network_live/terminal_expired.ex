defmodule PanicWeb.NetworkLive.TerminalExpired do
  @moduledoc """
  LiveView displayed when a terminal access token has expired or is invalid.

  This page provides a user-friendly message explaining that the QR code
  has expired and instructions on how to get a new one.
  """
  use PanicWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-4 py-16 text-center">
      <div class="mb-8">
        <svg
          class="mx-auto h-24 w-24 text-purple-400"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          aria-hidden="true"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
          />
        </svg>
      </div>

      <h1 class="text-3xl font-bold text-purple-100 mb-4">
        QR Code Expired
      </h1>

      <div class="prose prose-purple prose-lg mx-auto">
        <p class="text-purple-200 mb-6">
          The QR code you scanned has expired for security reasons.
          QR codes are only valid for 1 hour after they're generated.
        </p>

        <div class="bg-purple-900/20 border border-purple-700 rounded-lg p-6 mb-6">
          <h2 class="text-xl font-semibold text-purple-100 mb-3">
            How to get a new QR code:
          </h2>
          <ol class="text-left text-purple-200 space-y-2">
            <li>Find the screen displaying the PANIC! network</li>
            <li>Look for the QR code on the screen (it refreshes automatically)</li>
            <li>Scan the new QR code with your device</li>
          </ol>
        </div>

        <div class="space-y-4">
          <.link
            navigate={~p"/about"}
            class="inline-flex items-center px-6 py-3 border border-transparent text-base font-medium rounded-md text-purple-900 bg-purple-200 hover:bg-purple-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500"
          >
            Learn more about PANIC!
          </.link>

          <%= if @current_user do %>
            <div class="mt-4">
              <.link
                navigate={~p"/networks/#{@network_id}"}
                class="text-purple-300 hover:text-purple-100 underline"
              >
                View network details
              </.link>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"network_id" => network_id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "QR Code Expired")
     |> assign(:network_id, network_id)}
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "QR Code Expired")
     |> assign(:network_id, nil)}
  end
end
