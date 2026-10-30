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
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-2xl px-4 py-16 text-center">
        <.icon name="hero-clock" class="mx-auto mb-8 size-24 text-primary-content/70" />
        <h1 class="mb-4 text-3xl font-bold text-primary-content">QR Code Expired</h1>
        <p class="mb-6">
          A terminal opened from a QR code only stays open for a little while,
          so it's only for people at the installation. This one has closed.
        </p>
        <div class="card card-border border-base-300 bg-base-200 mb-6 text-left">
          <div class="card-body">
            <h2 class="card-title text-primary-content">How to get a new QR code:</h2>
            <ol class="list-decimal space-y-2 pl-6">
              <li>Find the screen displaying the PANIC! network</li>
              <li>Look for the QR code in its bottom right corner (it changes every minute)</li>
              <li>Scan the new QR code with your device</li>
            </ol>
          </div>
        </div>
        <div class="flex flex-col items-center gap-4">
          <.button navigate={~p"/about"} variant="primary">Learn more about PANIC!</.button>
          <.link :if={@current_user} navigate={~p"/networks/#{@network_id}"} class="link">
            View network details
          </.link>
        </div>
      </div>
    </Layouts.app>
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
