defmodule PanicWeb.NetworkLive.Show do
  use PanicWeb, :live_view

  alias Panic.{Networks, Platforms}
  alias Panic.Networks.Network

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    network = Networks.get_network!(id)
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:network, network)
     |> assign(:models, network.models)
    }
  end

  @impl true
  def handle_event("append-model", %{"model" => model}, socket) do
    {:ok, network} = Networks.append_model(socket.assigns.network, model)
    {:noreply, assign(socket, network: network, models: network.models)}
  end

  @impl true
  def handle_event("remove-last-model", _, socket) do
    {:ok, network} = Networks.remove_last_model(socket.assigns.network)
    {:noreply, assign(socket, network: network, models: network.models)}
  end

  defp page_title(:show), do: "Show Network"
  defp page_title(:edit), do: "Edit Network"

  defp last_model_output_type(%Network{models: []}), do: :text ## input prompt is always text
  defp last_model_output_type(%Network{models: models}), do: models |> List.last() |> Platforms.model_info() |> Map.get(:output)

  defp button_colour(input, last_output) when input != last_output, do: "bg-zinc-300"
  defp button_colour(:text, _), do: "bg-emerald-600"
  defp button_colour(:image, _), do: "bg-violet-700"

  def append_model_widget(assigns) do
    ~H"""
    <section class="p-4 mt-4 bg-zinc-100 rounded-lg">
      <h2 class="text-md font-semibold">Append Model</h2>
      <div class="mt-4 grid grid-cols-3 gap-2">
        <.button
          :for={{model, %{name: name, input: input}} <- Platforms.all_model_info()}
          class={
            button_colour(
              input,
              last_model_output_type(@network)
            )
          }
          phx-click={JS.push("append-model", value: %{model: model})}
        >
          <%= name %>
        </.button>
      </div>
      <.button class="mt-4 bg-red-700" phx-click="remove-last-model">
        Remove last
      </.button>
    </section>
    """
  end
end
