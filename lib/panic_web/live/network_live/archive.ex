defmodule PanicWeb.NetworkLive.Archive do
  use PanicWeb, :live_view

  alias Panic.Networks
  alias Panic.Models

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => network_id}, _, socket) do
    network = Networks.get_network!(network_id)
    grouped_runs = network
    |> Models.list_runs
    |> Enum.group_by(fn r -> r.first_run_id end)
    |> Enum.into([])

    {:noreply,
     socket
     |> assign(:page_title, "Network archive")
     |> assign(:network, network)
     |> assign(:grouped_runs, grouped_runs)
    }
  end

  def run_widget(assigns) do
    ~H"""
    <div class="relative block w-full text-center text-gray-800 bg-gray-200 shadow-lg dark:bg-gray-800 hover:bg-gray-300 dark:text-gray-400 dark:group-hover:text-gray-100">
      <div class="h-48 grid place-items-center overflow-hidden">
        <%= case Models.model_io(@run.model) do %>
          <% {_, :text} -> %>
            <div class="p-2 text-md text-left">
              <%= @run.output %>
            </div>
          <% {_, :image} -> %>
            <img class="w-full object-cover" src={@run.output} />
          <% {_, :audio} -> %>
            <audio autoplay controls={false} src={local_or_remote_url(@socket, @run.output)} />
            <Heroicons.Outline.volume_up class="w-12 h-12 mx-auto" />
        <% end %>
        <div class="absolute left-2 -bottom-6 text-xs">
          <%= @run.model |> String.split(~r/[:\/]/) |> List.last %>
        </div>
      </div>
    </div>
    """
  end

  def local_or_remote_url(socket, url) do
    if String.match?(url, ~r/https?:\/\//) do
      url
    else
      Routes.static_path(socket, "/model_outputs/" <> Path.basename(url))
    end
  end
end
